<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use App\Models\Traits\Auditable;

class DriverCollection extends Model
{
    use HasFactory, Auditable;

    protected $table = 'driver_collections';

    protected $fillable = [
        'driver_id',
        'amount',
        'collected_at',
        'collected_by',
        'notes',
    ];

    protected $casts = [
        'collected_at' => 'date',
        'amount' => 'integer',
        'driver_id' => 'integer',
        'collected_by' => 'integer',
    ];

    public function driver()
    {
        return $this->belongsTo(User::class, 'driver_id');
    }

    public function collector()
    {
        return $this->belongsTo(User::class, 'collected_by');
    }
}
