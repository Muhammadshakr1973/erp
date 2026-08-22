<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletes;
use Illuminate\Database\Eloquent\Factories\HasFactory;

class DeliveryTrip extends Model
{
    use HasFactory, SoftDeletes;
    protected $fillable = ['trip_number', 'driver_id', 'trip_date', 'status', 'total_orders', 'total_amount_collected', 'notes', 'started_at', 'completed_at', 'created_by'];
    protected $casts = ['trip_date' => 'date', 'started_at' => 'datetime', 'completed_at' => 'datetime'];
    const STATUS_PLANNED = 'planned';
    const STATUS_IN_PROGRESS = 'in_progress';
    const STATUS_COMPLETED = 'completed';
    public function driver()
    {
        return $this->belongsTo(User::class, 'driver_id');
    }
    public function orders()
    {
        return $this->hasMany(DeliveryTripOrder::class);
    }
    public function creator()
    {
        return $this->belongsTo(User::class, 'created_by');
    }
}
