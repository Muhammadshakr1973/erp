<?php

namespace App\Exceptions;

use Exception;
use App\Models\SalesOrder;

class ConcurrencyConflictException extends Exception
{
    protected SalesOrder $order;

    public function __construct(SalesOrder $order, string $message = "")
    {
        parent::__construct($message ?: 'هەڵەی هاوکاتی: داتاکانی ئەم پسوڵەیە پێشتر لەلایەن ئامێرێکی ترەوە دەستکاری کراون. تکایە پسوڵەکە نوێ بکەرەوە.');
        $this->order = $order;
    }

    public function getOrder(): SalesOrder
    {
        return $this->order;
    }
}
