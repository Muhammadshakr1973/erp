<?php

namespace App\Http\Requests\Api\V1\Delivery;

use Illuminate\Foundation\Http\FormRequest;

class StoreDeliveryTripRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    protected function prepareForValidation(): void
    {
        if ($this->has('orders') && !$this->has('order_ids') && is_array($this->orders)) {
            $ids = [];
            foreach ($this->orders as $o) {
                if (is_array($o) && isset($o['sales_order_id'])) {
                    $ids[] = $o['sales_order_id'];
                } elseif (is_numeric($o)) {
                    $ids[] = $o;
                }
            }
            $this->merge(['order_ids' => $ids]);
        }
    }

    public function rules(): array
    {
        return [
            'driver_id' => ['required', 'integer', 'exists:users,id'],
            'trip_date' => ['required', 'date'],
            'notes'     => ['nullable', 'string'],

            // ئەو پسوڵانەی دەدرێن بە شۆفێرەکە
            'order_ids'   => ['required', 'array', 'min:1'],
            'order_ids.*' => ['required', 'integer', 'exists:sales_orders,id'],
        ];
    }
}
