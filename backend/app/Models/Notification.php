<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class Notification extends Model
{
    use HasFactory;
    protected $fillable = ['user_id', 'type', 'title', 'body', 'data', 'is_read', 'read_at'];
    protected $casts = ['data' => 'array', 'is_read' => 'boolean', 'read_at' => 'datetime'];
    const TYPE_ORDER = 'order';
    const TYPE_PAYMENT = 'payment';
    const TYPE_STOCK = 'stock';
    const TYPE_COMMISSION = 'commission';
    const TYPE_SYSTEM = 'system';
    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
    public function scopeUnread($q)
    {
        return $q->where('is_read', false);
    }
    public function scopeOfType($q, $type)
    {
        return $q->where('type', $type);
    }
    public function markAsRead(): void
    {
        $this->update(['is_read' => true, 'read_at' => now()]);
    }
}
