<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class DeviceToken extends Model
{
    use HasFactory;
    protected $fillable = ['user_id', 'token', 'device_token', 'device_type', 'device_name', 'is_active', 'last_used_at'];
    protected $casts = [
        'is_active' => 'boolean',
        'last_used_at' => 'datetime',
    ];

    public function getTokenAttribute(?string $value): ?string
    {
        return $value ?? $this->attributes['device_token'] ?? null;
    }

    public function getDeviceTokenAttribute(?string $value): ?string
    {
        return $value ?? $this->attributes['token'] ?? null;
    }
    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
