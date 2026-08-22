<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Factories\HasFactory;

class RouteSalesman extends Model
{
    use HasFactory;
    protected $fillable = ['route_id', 'salesman_id', 'is_active', 'assigned_at'];
    protected $casts = ['is_active' => 'boolean', 'assigned_at' => 'datetime'];
    public function route()
    {
        return $this->belongsTo(Route::class);
    }
    public function salesman()
    {
        return $this->belongsTo(User::class, 'salesman_id');
    }
}
