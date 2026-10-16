<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletes;
use Illuminate\Database\Eloquent\Factories\HasFactory;

class Warehouse extends Model
{
    use HasFactory, SoftDeletes;
    protected $fillable = ['name', 'code', 'address', 'phone', 'is_main', 'is_active', 'type'];
    protected $casts = ['is_main' => 'boolean', 'is_active' => 'boolean'];

    public function isVan(): bool
    {
        return strtoupper($this->type ?? '') === 'VAN' || str_contains($this->name, 'کاشڤان');
    }

    public function stocks()
    {
        return $this->hasMany(WarehouseStock::class);
    }
    public function transactions()
    {
        return $this->hasMany(StockTransaction::class);
    }
}
