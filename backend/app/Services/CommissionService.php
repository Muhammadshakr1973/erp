<?php

namespace App\Services;

use App\Models\SalesmanCommission;
use App\Models\SalesmanCommissionDetail;
use App\Models\SalesOrder;
use App\Models\User;
use Illuminate\Contracts\Pagination\LengthAwarePaginator;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class CommissionService
{
    /**
     * پیشاندانی سەرەتایی (Preview) پسوڵە شایستەکان بۆ هەژمارکردنی کۆمسیۆن پێش پاشەکەوتکردن
     */
    public function previewEligibleOrders(int $salesmanId, string $periodFrom, string $periodTo): array
    {
        $salesman = User::findOrFail($salesmanId);

        if ($periodFrom > $periodTo) {
            throw ValidationException::withMessages([
                'period' => 'بەرواری سەرەتا دەبێت پێشتر یان یەکسان بێت بە بەرواری کۆتایی.',
            ]);
        }

        $rate = (float) ($salesman->commission_rate ?? 0);

        $orders = SalesOrder::with('customer:id,name,phone')
            ->where('salesman_id', $salesman->id)
            ->where('status', SalesOrder::STATUS_DELIVERED)
            ->whereBetween('delivered_at', [$periodFrom . ' 00:00:00', $periodTo . ' 23:59:59'])
            ->whereDoesntHave('commissionDetail.commission', function ($q) {
                $q->whereIn('status', [
                    SalesmanCommission::STATUS_CALCULATED,
                    SalesmanCommission::STATUS_APPROVED,
                    SalesmanCommission::STATUS_PAID,
                ]);
            })
            ->orderBy('delivered_at')
            ->get();

        $totalSales = (int) $orders->sum('total_amount');
        $totalProfit = (int) $orders->sum('total_profit');
        $estimatedCommission = (int) round(($totalProfit * $rate) / 100);

        $orderItems = $orders->map(function ($order) use ($rate) {
            $orderProfit = (int) $order->total_profit;
            $orderCommission = (int) round(($orderProfit * $rate) / 100);

            return [
                'id'                 => $order->id,
                'order_number'       => $order->order_number,
                'customer_id'        => $order->customer_id,
                'customer_name'      => $order->customer?->name ?? 'N/A',
                'customer_phone'     => $order->customer?->phone ?? 'N/A',
                'delivered_at'       => $order->delivered_at?->toIso8601String(),
                'total_amount'       => (int) $order->total_amount,
                'total_profit'       => $orderProfit,
                'commission_rate'    => $rate,
                'commission_amount'  => $orderCommission,
            ];
        });

        return [
            'salesman' => [
                'id'              => $salesman->id,
                'name'            => $salesman->name,
                'phone'           => $salesman->phone,
                'commission_rate' => $rate,
            ],
            'period_from'          => $periodFrom,
            'period_to'            => $periodTo,
            'eligible_orders_count'=> $orders->count(),
            'total_sales'          => $totalSales,
            'total_profit'         => $totalProfit,
            'commission_rate'      => $rate,
            'estimated_commission' => $estimatedCommission,
            'orders'               => $orderItems,
        ];
    }

    /**
     * هەژمارکردنی فەرمی کۆمسیۆن بۆ مەندوب و تۆمارکردنی خشتەی سەرەکی و وردەکارییەکان
     */
    public function calculateCommission(array $data, User $user): SalesmanCommission
    {
        return DB::transaction(function () use ($data, $user) {
            $salesman = User::lockForUpdate()->findOrFail($data['salesman_id']);

            $periodFrom = $data['period_from'];
            $periodTo = $data['period_to'];

            if ($periodFrom > $periodTo) {
                throw ValidationException::withMessages([
                    'period' => 'بەرواری سەرەتا دەبێت پێشتر یان یەکسان بێت بە بەرواری کۆتایی.',
                ]);
            }

            // پشکنینی ڕێگری لە دووبارەبوونەوە: ئایا کۆمسیۆنێکی چالاک لەم مەودایەدا هەیە؟
            $existingActive = SalesmanCommission::where('salesman_id', $salesman->id)
                ->where('period_from', $periodFrom)
                ->where('period_to', $periodTo)
                ->whereIn('status', [
                    SalesmanCommission::STATUS_CALCULATED,
                    SalesmanCommission::STATUS_APPROVED,
                    SalesmanCommission::STATUS_PAID,
                ])
                ->exists();

            if ($existingActive) {
                throw ValidationException::withMessages([
                    'period' => 'لە نێوان ئەم بەروارانەدا پێشتر کۆمسیۆنێکی چالاک بۆ ئەم مەندوبە هەژمار کراوە.',
                ]);
            }

            // هێنانی پسوڵە گەیندراوە شایستەکان کە پێشتر لە هیچ کۆمسیۆنێکی چالاکدا بەکارنەهاتوون
            $orders = SalesOrder::where('salesman_id', $salesman->id)
                ->where('status', SalesOrder::STATUS_DELIVERED)
                ->whereBetween('delivered_at', [$periodFrom . ' 00:00:00', $periodTo . ' 23:59:59'])
                ->whereDoesntHave('commissionDetail.commission', function ($q) {
                    $q->whereIn('status', [
                        SalesmanCommission::STATUS_CALCULATED,
                        SalesmanCommission::STATUS_APPROVED,
                        SalesmanCommission::STATUS_PAID,
                    ]);
                })
                ->lockForUpdate()
                ->get();

            if ($orders->isEmpty()) {
                throw ValidationException::withMessages([
                    'orders' => 'هیچ پسوڵەیەکی گەیندراوی شایستە بۆ ئەم مەندوبە لەم ماوەیەدا نییە.',
                ]);
            }

            $totalSales = (int) $orders->sum('total_amount');
            $totalProfit = (int) $orders->sum('total_profit');

            // وەرگرتنی ڕێژەی کۆمسیۆنی مەندوب لەم ساتەدا (Historical Snapshot)
            $rate = (float) ($salesman->commission_rate ?? 0);

            // هەژمارکردنی پارەی کۆمسیۆن بەپێی قازانج (DEC-005)
            $commissionAmount = (int) round(($totalProfit * $rate) / 100);

            // ١. تۆمارکردنی خشتەی سەرەکی کۆمسیۆن
            $commission = SalesmanCommission::create([
                'salesman_id'       => $salesman->id,
                'period_from'       => $periodFrom,
                'period_to'         => $periodTo,
                'total_sales'       => $totalSales,
                'profit_amount'     => $totalProfit,
                'total_profit'      => $totalProfit,
                'commission_rate'   => $rate,
                'commission_amount' => $commissionAmount,
                'status'            => SalesmanCommission::STATUS_CALCULATED,
                'calculated_by'     => $user->id,
                'notes'             => $data['notes'] ?? null,
            ]);

            // ٢. تۆمارکردنی وردەکارییەکان بۆ هەر پسوڵەیەک لەگەڵ چەسپاندنی مێژوویی قازانج و کۆمسیۆن
            foreach ($orders as $order) {
                $orderProfit = (int) $order->total_profit;
                $orderCommission = (int) round(($orderProfit * $rate) / 100);

                SalesmanCommissionDetail::create([
                    'salesman_commission_id' => $commission->id,
                    'sales_order_id'         => $order->id,
                    'sales_amount'           => (int) $order->total_amount,
                    'profit_amount'          => $orderProfit,
                    'commission_amount'      => $orderCommission,
                ]);
            }

            // تۆمارکردنی لۆگی چاودێری
            app(\App\Services\AuditService::class)->log([
                'action'      => 'COMMISSION_CALCULATE',
                'entity_type' => 'SalesmanCommission',
                'entity_id'   => $commission->id,
                'table_name'  => 'salesman_commissions',
                'old_values'  => null,
                'new_values'  => [
                    'salesman_id'       => $salesman->id,
                    'salesman_name'     => $salesman->name,
                    'period_from'       => $periodFrom,
                    'period_to'         => $periodTo,
                    'total_sales'       => $totalSales,
                    'total_profit'      => $totalProfit,
                    'commission_rate'   => $rate,
                    'commission_amount' => $commissionAmount,
                    'orders_count'      => $orders->count(),
                ],
                'description' => "کۆمسیۆنی مەندوب {$salesman->name} هەژمارکرا بە بڕی {$commissionAmount} د.ع بۆ ماوەی {$periodFrom} تا {$periodTo} لەسەر {$orders->count()} پسوڵە",
                'user'        => $user,
            ]);

            return $commission->load(['salesman', 'details.order.customer', 'calculator']);
        });
    }

    /**
     * پەسەندکردنی کۆمسیۆن لەلایەن بەڕێوەبەر یان خاوەندارێتەوە (CALCULATED -> APPROVED)
     */
    public function approveCommission(int $commissionId, User $user, ?string $notes = null): SalesmanCommission
    {
        return DB::transaction(function () use ($commissionId, $user, $notes) {
            $commission = SalesmanCommission::with(['salesman', 'details'])->lockForUpdate()->findOrFail($commissionId);

            if ($commission->status !== SalesmanCommission::STATUS_CALCULATED) {
                if ($commission->status === SalesmanCommission::STATUS_APPROVED) {
                    throw ValidationException::withMessages([
                        'status' => 'ئەم کۆمسیۆنە پێشتر پەسەند کراوە.',
                    ]);
                }
                if ($commission->status === SalesmanCommission::STATUS_PAID) {
                    throw ValidationException::withMessages([
                        'status' => 'ئەم کۆمسیۆنە پێشتر پارەکەی دراوە.',
                    ]);
                }
                if ($commission->status === SalesmanCommission::STATUS_CANCELLED) {
                    throw ValidationException::withMessages([
                        'status' => 'ئەم کۆمسیۆنە هەڵوەشێنراوەتەوە و ناتوانرێت پەسەند بکرێت.',
                    ]);
                }
            }

            $oldValues = [
                'status'      => $commission->status,
                'approved_by' => $commission->approved_by,
                'approved_at' => $commission->approved_at,
            ];

            $commission->status = SalesmanCommission::STATUS_APPROVED;
            $commission->approved_by = $user->id;
            $commission->approved_at = now();

            if ($notes !== null) {
                $commission->notes = $notes;
            }

            $commission->save();

            $newValues = [
                'status'      => $commission->status,
                'approved_by' => $commission->approved_by,
                'approved_at' => $commission->approved_at?->toIso8601String(),
                'notes'       => $commission->notes,
            ];

            app(\App\Services\AuditService::class)->log([
                'action'      => 'COMMISSION_APPROVE',
                'entity_type' => 'SalesmanCommission',
                'entity_id'   => $commission->id,
                'table_name'  => 'salesman_commissions',
                'old_values'  => $oldValues,
                'new_values'  => $newValues,
                'description' => "کۆمسیۆنی #{$commission->id} بۆ مەندوب {$commission->salesman?->name} بە بڕی {$commission->commission_amount} د.ع پەسەند کرا",
                'user'        => $user,
            ]);

            return $commission->load(['salesman', 'details.order.customer', 'calculator', 'approver']);
        });
    }

    /**
     * تۆمارکردنی پارەدانی کۆمسیۆن بۆ مەندوب (APPROVED -> PAID)
     */
    public function payCommission(int $commissionId, User $user, array $paymentData): SalesmanCommission
    {
        return DB::transaction(function () use ($commissionId, $user, $paymentData) {
            $commission = SalesmanCommission::with(['salesman', 'details'])->lockForUpdate()->findOrFail($commissionId);

            if ($commission->status === SalesmanCommission::STATUS_PAID) {
                throw ValidationException::withMessages([
                    'status' => 'پارەی ئەم کۆمسیۆنە پێشتر دراوە و ناتوانرێت دووبارە بدرێتەوە.',
                ]);
            }

            if ($commission->status === SalesmanCommission::STATUS_CALCULATED) {
                throw ValidationException::withMessages([
                    'status' => 'دەبێت سەرەتا کۆمسیۆنەکە پەسەند بکرێت پێش ئەوەی پارەکەی بدرێت.',
                ]);
            }

            if ($commission->status === SalesmanCommission::STATUS_CANCELLED) {
                throw ValidationException::withMessages([
                    'status' => 'ئەم کۆمسیۆنە هەڵوەشێنراوەتەوە و ناکرێت پارەی پێ بدرێت.',
                ]);
            }

            $oldValues = [
                'status'         => $commission->status,
                'paid_by'        => $commission->paid_by,
                'paid_at'        => $commission->paid_at,
                'payment_method' => $commission->payment_method,
            ];

            $paymentMethod = strtolower($paymentData['payment_method'] ?? 'cash');
            $paidAt = !empty($paymentData['paid_at']) ? $paymentData['paid_at'] : now();

            $commission->status = SalesmanCommission::STATUS_PAID;
            $commission->paid_by = $user->id;
            $commission->paid_at = $paidAt;
            $commission->payment_method = $paymentMethod;

            if (!empty($paymentData['notes'])) {
                $commission->notes = $paymentData['notes'];
            }

            $commission->save();

            $newValues = [
                'status'         => $commission->status,
                'paid_by'        => $commission->paid_by,
                'paid_at'        => $commission->paid_at?->toIso8601String(),
                'payment_method' => $commission->payment_method,
                'notes'          => $commission->notes,
            ];

            app(\App\Services\AuditService::class)->log([
                'action'      => 'COMMISSION_PAY',
                'entity_type' => 'SalesmanCommission',
                'entity_id'   => $commission->id,
                'table_name'  => 'salesman_commissions',
                'old_values'  => $oldValues,
                'new_values'  => $newValues,
                'description' => "پارەدانی کۆمسیۆنی #{$commission->id} بە بڕی {$commission->commission_amount} د.ع بە ڕێگەی {$paymentMethod} بۆ مەندوب {$commission->salesman?->name} تەواوکرا",
                'user'        => $user,
            ]);

            return $commission->load(['salesman', 'details.order.customer', 'calculator', 'approver', 'payer']);
        });
    }

    /**
     * هەڵوەشاندنەوە یان پاشگەزبوونەوە لە کۆمسیۆن (CANCEL / REVERSE)
     * لە کاتی هەڵوەشاندنەوەدا پسوڵەکان ئازاد دەبنەوە بۆ هەژمارکردنەوەی نوێ
     */
    public function cancelCommission(int $commissionId, User $user, string $reason): SalesmanCommission
    {
        return DB::transaction(function () use ($commissionId, $user, $reason) {
            $commission = SalesmanCommission::with(['salesman', 'details'])->lockForUpdate()->findOrFail($commissionId);

            if ($commission->status === SalesmanCommission::STATUS_CANCELLED) {
                throw ValidationException::withMessages([
                    'status' => 'ئەم کۆمسیۆنە پێشتر هەڵوەشێنراوەتەوە.',
                ]);
            }

            $oldValues = [
                'status'              => $commission->status,
                'cancelled_by'        => $commission->cancelled_by,
                'cancelled_at'        => $commission->cancelled_at,
                'cancellation_reason' => $commission->cancellation_reason,
            ];

            $commission->status = SalesmanCommission::STATUS_CANCELLED;
            $commission->cancelled_by = $user->id;
            $commission->cancelled_at = now();
            $commission->cancellation_reason = $reason;
            $commission->save();

            $newValues = [
                'status'              => $commission->status,
                'cancelled_by'        => $commission->cancelled_by,
                'cancelled_at'        => $commission->cancelled_at?->toIso8601String(),
                'cancellation_reason' => $commission->cancellation_reason,
            ];

            app(\App\Services\AuditService::class)->log([
                'action'      => 'COMMISSION_CANCEL',
                'entity_type' => 'SalesmanCommission',
                'entity_id'   => $commission->id,
                'table_name'  => 'salesman_commissions',
                'old_values'  => $oldValues,
                'new_values'  => $newValues,
                'description' => "کۆمسیۆنی #{$commission->id} بۆ مەندوب {$commission->salesman?->name} هەڵوەشێنرایەوە بە هۆکاری: {$reason}",
                'user'        => $user,
            ]);

            return $commission->load(['salesman', 'details.order.customer', 'calculator', 'approver', 'payer', 'canceller']);
        });
    }

    /**
     * گەڕان و فلتەرکردنی لیستی کۆمسیۆنەکان
     */
    public function getCommissions(array $filters, ?User $user = null): LengthAwarePaginator
    {
        $query = SalesmanCommission::with([
            'salesman:id,name,phone,commission_rate',
            'calculator:id,name',
            'approver:id,name',
            'payer:id,name',
            'canceller:id,name',
            'details.order.customer:id,name',
        ]);

        // ئەگەر بەکارهێنەر مەندوب بێت و ئادمین نەبێت، تەنها هی خۆی دەبینێت
        if ($user && !$user->isAdmin() && !$user->isOwner()) {
            $query->where('salesman_id', $user->id);
        } elseif (!empty($filters['salesman_id'])) {
            $query->where('salesman_id', (int) $filters['salesman_id']);
        }

        if (!empty($filters['status'])) {
            $query->where('status', strtolower($filters['status']));
        }

        if (!empty($filters['period_from'])) {
            $query->where('period_from', '>=', $filters['period_from']);
        }

        if (!empty($filters['period_to'])) {
            $query->where('period_to', '<=', $filters['period_to']);
        }

        if (!empty($filters['search'])) {
            $search = $filters['search'];
            $query->where(function ($q) use ($search) {
                $q->whereHas('salesman', function ($sq) use ($search) {
                    $sq->where('name', 'like', "%{$search}%")
                       ->orWhere('phone', 'like', "%{$search}%");
                })->orWhere('notes', 'like', "%{$search}%");
            });
        }

        $perPage = min((int) ($filters['per_page'] ?? 20), 100);

        return $query->orderByDesc('id')->paginate($perPage);
    }

    /**
     * پوختەی ئاماری کۆمسیۆنەکان
     */
    public function getCommissionSummary(array $filters = []): array
    {
        $query = SalesmanCommission::query();

        if (!empty($filters['salesman_id'])) {
            $query->where('salesman_id', (int) $filters['salesman_id']);
        }

        if (!empty($filters['period_from'])) {
            $query->where('period_from', '>=', $filters['period_from']);
        }

        if (!empty($filters['period_to'])) {
            $query->where('period_to', '<=', $filters['period_to']);
        }

        $totalCalculated = (clone $query)->where('status', SalesmanCommission::STATUS_CALCULATED)->sum('commission_amount');
        $totalApproved   = (clone $query)->where('status', SalesmanCommission::STATUS_APPROVED)->sum('commission_amount');
        $totalPaid       = (clone $query)->where('status', SalesmanCommission::STATUS_PAID)->sum('commission_amount');
        $totalCancelled  = (clone $query)->where('status', SalesmanCommission::STATUS_CANCELLED)->sum('commission_amount');

        $countCalculated = (clone $query)->where('status', SalesmanCommission::STATUS_CALCULATED)->count();
        $countApproved   = (clone $query)->where('status', SalesmanCommission::STATUS_APPROVED)->count();
        $countPaid       = (clone $query)->where('status', SalesmanCommission::STATUS_PAID)->count();
        $countCancelled  = (clone $query)->where('status', SalesmanCommission::STATUS_CANCELLED)->count();

        $totalSalesAll  = (clone $query)->whereIn('status', [SalesmanCommission::STATUS_CALCULATED, SalesmanCommission::STATUS_APPROVED, SalesmanCommission::STATUS_PAID])->sum('total_sales');
        $totalProfitAll = (clone $query)->whereIn('status', [SalesmanCommission::STATUS_CALCULATED, SalesmanCommission::STATUS_APPROVED, SalesmanCommission::STATUS_PAID])->sum('total_profit');

        return [
            'total_sales'      => (int) $totalSalesAll,
            'total_profit'     => (int) $totalProfitAll,
            'calculated'       => [
                'count'  => $countCalculated,
                'amount' => (int) $totalCalculated,
            ],
            'approved'         => [
                'count'  => $countApproved,
                'amount' => (int) $totalApproved,
            ],
            'paid'             => [
                'count'  => $countPaid,
                'amount' => (int) $totalPaid,
            ],
            'cancelled'        => [
                'count'  => $countCancelled,
                'amount' => (int) $totalCancelled,
            ],
        ];
    }
}
