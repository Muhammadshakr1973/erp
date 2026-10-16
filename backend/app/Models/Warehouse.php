<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletes;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Support\Facades\Schema;

class Warehouse extends Model
{
    use HasFactory, SoftDeletes;

    public const TYPE_PHYSICAL_DIRECT = 'PHYSICAL_DIRECT';
    public const TYPE_PHYSICAL_RESERVE = 'PHYSICAL_RESERVE';
    public const TYPE_VAN = 'VAN';

    protected $fillable = ['name', 'code', 'address', 'phone', 'is_main', 'is_active', 'type'];
    protected $casts = ['is_main' => 'boolean', 'is_active' => 'boolean'];

    public function isVan(): bool
    {
        $normalizedType = strtoupper($this->type ?? '');
        return $normalizedType === self::TYPE_VAN || str_contains($this->name, 'کاشڤان');
    }

    public function isReserve(): bool
    {
        return strtoupper($this->type ?? '') === self::TYPE_PHYSICAL_RESERVE;
    }

    public function isDirectSale(): bool
    {
        $t = strtoupper($this->type ?? '');
        return $t === self::TYPE_PHYSICAL_DIRECT || ($t === 'PHYSICAL' && !$this->isVan() && !$this->isReserve());
    }

    public function isPhysical(): bool
    {
        return !$this->isVan();
    }

    public function canSell(): bool
    {
        return !$this->isReserve();
    }

    public function users(): BelongsToMany
    {
        return $this->belongsToMany(User::class, 'warehouse_user')->withTimestamps();
    }

    public function stocks(): HasMany
    {
        return $this->hasMany(WarehouseStock::class);
    }

    public function transactions(): HasMany
    {
        return $this->hasMany(StockTransaction::class);
    }
}
