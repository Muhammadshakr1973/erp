<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Factories\HasFactory;

class RouteSalesman extends Model
{
    use HasFactory;
    protected $table = 'route_salesmen';
    protected $fillable = ['route_id', 'salesman_id', 'is_active', 'work_date', 'assigned_by'];
    protected $casts = ['is_active' => 'boolean', 'assigned_at' => 'datetime'];

    protected static function booted()
    {
        static::saving(function ($item) {
            if (empty($item->work_date)) {
                $item->work_date = now()->toDateString();
            }
        });
    }
    public function route()
    {
        return $this->belongsTo(Route::class);
    }
    public function salesman()
    {
        return $this->belongsTo(User::class, 'salesman_id');
    }
}
