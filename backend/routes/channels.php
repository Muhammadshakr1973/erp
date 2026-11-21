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

    // Portal customer owns their order
    if (method_exists($user, 'isCustomer') && $user->isCustomer()) {
        return (int) ($user->customer?->id ?? -1) === (int) $order->customer_id;
    }

    // Warehouse users with access to the order's warehouse
    if ($user->role?->name === 'warehouse' || $user->hasPermission('stock.pack')) {
        if (method_exists($user, 'hasWarehouseAccess')) {
            if ($user->hasWarehouseAccess($order->warehouse_id)) {
                return true;
            }
        } elseif (!$user->warehouse_id || (int) $user->warehouse_id === (int) $order->warehouse_id) {
            return true;
        }
    }

    // Drivers assigned to a delivery trip containing this order
    if ($user->role?->name === 'driver' || $user->hasPermission('delivery.update')) {
        try {
            $onTrip = \Illuminate\Support\Facades\DB::table('delivery_trip_orders')
                ->join('delivery_trips', 'delivery_trip_orders.delivery_trip_id', '=', 'delivery_trips.id')
                ->where('delivery_trip_orders.sales_order_id', $order->id)
                ->where('delivery_trips.driver_id', $user->id)
                ->exists();
            if ($onTrip) {
                return true;
            }
        } catch (\Throwable $e) {
            return false;
        }
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

Broadcast::channel('orders', function (User $user) {
    return (bool) $user->is_active;
});

Broadcast::channel('products', function (User $user) {
    return (bool) $user->is_active;
});

Broadcast::channel('customers', function (User $user) {
    return (bool) $user->is_active;
});

Broadcast::channel('delivery-trips', function (User $user) {
    return (bool) $user->is_active;
});

Broadcast::channel('commissions', function (User $user) {
    return (bool) $user->is_active;
});

Broadcast::channel('suppliers', function (User $user) {
    return (bool) $user->is_active;
});

Broadcast::channel('categories', function (User $user) {
    return (bool) $user->is_active;
});

Broadcast::channel('routes', function (User $user) {
    return (bool) $user->is_active;
});

Broadcast::channel('users', function (User $user) {
    return (bool) $user->is_active;
});

Broadcast::channel('stock-transfers', function (User $user) {
    return (bool) $user->is_active;
});

Broadcast::channel('purchases', function (User $user) {
    return (bool) $user->is_active;
});

Broadcast::channel('warehouses', function (User $user) {
    return (bool) $user->is_active;
});

Broadcast::channel('settings', function (User $user) {
    return (bool) $user->is_active && ($user->isOwner() || $user->isAdmin());
});

Broadcast::channel('audit-logs', function (User $user) {
    return (bool) $user->is_active && ($user->isOwner() || $user->isAdmin());
});

Broadcast::channel('user-notifications.{userId}', function (User $user, int $userId) {
    return (int) $user->id === (int) $userId;
});

