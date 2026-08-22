<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Factories\HasFactory;

class StockTransferItem extends Model
{
    use HasFactory;
    protected $fillable = ['stock_transfer_id', 'product_id', 'quantity', 'quantity_received', 'notes'];
    public function transfer()
    {
        return $this->belongsTo(StockTransfer::class, 'stock_transfer_id');
    }
    public function product()
    {
        return $this->belongsTo(Product::class);
    }
}
