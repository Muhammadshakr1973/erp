<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class DeviceToken extends Model
{
    use HasFactory;
    protected $fillable = ['user_id', 'device_token', 'device_type', 'device_name', 'is_active'];
    protected $casts = ['is_active' => 'boolean'];
    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
