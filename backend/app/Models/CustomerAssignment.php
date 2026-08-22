<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Factories\HasFactory;

class CustomerAssignment extends Model
{
    use HasFactory;
    public $timestamps = true;
    protected $fillable = ['customer_id', 'route_id', 'assigned_by', 'assigned_at'];
    protected $casts = ['assigned_at' => 'datetime'];
    public function customer()
    {
        return $this->belongsTo(Customer::class);
    }
    public function route()
    {
        return $this->belongsTo(Route::class);
    }
}
