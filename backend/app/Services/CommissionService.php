<?php

namespace App\Services;

use App\Models\User;
use App\Models\SalesOrder;
use App\Models\SalesmanCommission;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class CommissionService
{
    public function calculateCommission(array $data, $user): SalesmanCommission
    {
        return DB::transaction(function () use ($data, $user) {

            $salesman = User::findOrFail($data['salesman_id']);

            // پشکنین: بزانین ئایا لەم بەروارەدا پێشتر کۆمسیۆن هەژمار کراوە؟ (بۆ ڕێگری لە دووبارەبوونەوە)
            $exists = SalesmanCommission::where('salesman_id', $salesman->id)
                ->where('period_from', $data['period_from'])
                ->where('period_to', $data['period_to'])
                ->exists();

            if ($exists) {
                throw ValidationException::withMessages([
                    'period' => 'لە نێوان ئەم بەروارانەدا پێشتر کۆمسیۆن بۆ ئەم مەندوبە هەژمار کراوە.'
                ]);
            }

            // هێنانی هەموو پسوڵە گەیندراوەکانی ئەم مەندوبە لەم ماوەیەدا
            // تێبینی: ئەو پسوڵانە ناهێنین کە پێشتر چونەتە ناو کۆمسیۆنێکی ترەوە (بە leftJoin یان whereDoesntHave)
            $orders = SalesOrder::where('salesman_id', $salesman->id)
                ->where('status', 'DELIVERED')
                ->whereBetween('delivered_at', [$data['period_from'] . ' 00:00:00', $data['period_to'] . ' 23:59:59'])
                ->whereDoesntHave('commissionDetails') // ئەگەر relationـت دانابێت، یان سادەتر: دڵنیابوون لەوەی نەچووەتە commission_details
                ->get();

            if ($orders->isEmpty()) {
                throw ValidationException::withMessages([
                    'orders' => 'هیچ پسوڵەیەکی گەیندراو نییە بۆ ئەم مەندوبە لەم ماوەیەدا.'
                ]);
            }

            $totalSales = $orders->sum('total_amount');
            $totalProfit = $orders->sum('total_profit'); // قازانجی ساغ

            // ڕێژەی کۆمسیۆنی مەندوب (نموونە: 40 واتە 40%)
            $rate = $salesman->commission_rate;

            // هەژمارکردنی پارەی کۆمسیۆن لەسەر قازانج نەک فرۆشتن (DEC-005)
            $commissionAmount = ($totalProfit * $rate) / 100;

            // ١. دروستکردنی پەڕەی سەرەکی کۆمسیۆن
            $commission = SalesmanCommission::create([
                'salesman_id'       => $salesman->id,
                'period_from'       => $data['period_from'],
                'period_to'         => $data['period_to'],
                'total_sales'       => $totalSales,
                'profit_amount'     => $totalProfit,
                'total_profit'      => $totalProfit,
                'commission_rate'   => $rate,
                'commission_amount' => $commissionAmount,
                'status'            => 'calculated',
                'calculated_by'     => $user->id,
            ]);

            // ٢. دروستکردنی وردەکارییەکان (Details) بۆ هەر پسوڵەیەک
            foreach ($orders as $order) {
                $orderCommission = ($order->total_profit * $rate) / 100;

                $commission->details()->create([
                    'sales_order_id'    => $order->id,
                    'sales_amount'      => $order->total_amount,
                    'profit_amount'     => $order->total_profit,
                    'commission_amount' => $orderCommission,
                ]);
            }

            return $commission;
        });
    }
}
