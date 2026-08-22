<?php

namespace App\Http\Requests\Api\V1\Delivery;

use Illuminate\Foundation\Http\FormRequest;

class StoreDeliveryTripRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
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
