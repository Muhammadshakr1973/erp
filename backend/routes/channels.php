<?php

use App\Models\SalesOrder;
use App\Models\User;
use Illuminate\Support\Facades\Broadcast;

Broadcast::channel('sales-order.{id}', function (User $user, int $id) {
    $order = SalesOrder::find($id);
    if (!$order) {
        return false;
    }

    // Admins and owners always have access
    if ($user->isAdmin() || $user->isOwner()) {
        return true;
    }

    // Salesman of the order has access
    if ((int) $order->salesman_id === (int) $user->id) {
        return true;
    }

    // Check customer assignment (direct or route assignment)
    try {
        $hasDirectAssignment = \Illuminate\Support\Facades\DB::table('customer_assignments')
            ->where('customer_id', $order->customer_id)
            ->where('salesman_id', $user->id)
            ->where('assigned_from', '<=', now()->toDateString())
            ->where(function ($q) {
                $q->whereNull('assigned_until')
                  ->orWhere('assigned_until', '>=', now()->toDateString());
            })
            ->exists();

        if ($hasDirectAssignment) {
            return true;
        }

        $customer = \App\Models\Customer::find($order->customer_id);
        if ($customer) {
            $hasRouteAssignment = \Illuminate\Support\Facades\DB::table('route_salesmen')
                ->where('route_id', $customer->route_id)
                ->where('salesman_id', $user->id)
                ->where('work_date', now()->toDateString())
                ->exists();

            if ($hasRouteAssignment) {
                return true;
            }
        }
    } catch (\Throwable $e) {
        return false;
    }

    return false;
});
