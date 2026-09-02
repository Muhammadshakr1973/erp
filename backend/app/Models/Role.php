<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Relations\HasMany;
use App\Models\Traits\Auditable;

/**
 * Role Model - V4.0
 * @property int $id
 * @property string $name owner|admin|salesman|warehouse|driver
 */
class Role extends Model
{
    use HasFactory, Auditable;
    protected $fillable = ['name', 'display_name', 'description', 'permissions', 'is_system'];
    protected $casts = ['permissions' => 'array', 'is_system' => 'boolean'];

    public const OWNER = 'owner';
    public const ADMIN = 'admin';
    public const SALESMAN = 'salesman';
    public const WAREHOUSE = 'warehouse';
    public const DRIVER = 'driver';

    protected static function booted()
    {
        static::creating(function ($role) {
            if (empty($role->display_name)) {
                $role->display_name = ucfirst($role->name);
            }
        });
    }

    public function users(): HasMany
    {
        return $this->hasMany(User::class);
    }
}
