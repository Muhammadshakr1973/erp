<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletes;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Route extends Model
{
    use HasFactory, SoftDeletes;
    protected $table = 'routes';
    protected $fillable = ['name', 'code', 'description', 'color', 'is_active'];
    protected $casts = ['is_active' => 'boolean'];
    public function customers(): HasMany
    {
        return $this->hasMany(Customer::class);
    }
    public function salesmen(): HasMany
    {
        return $this->hasMany(RouteSalesman::class);
    }
    public function assignments(): HasMany
    {
        return $this->hasMany(CustomerAssignment::class);
    }
}
