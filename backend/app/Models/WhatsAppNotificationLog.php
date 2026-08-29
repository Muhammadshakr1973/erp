<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class WhatsAppNotificationLog extends Model
{
    use HasFactory;

    protected $table = 'whatsapp_notification_logs';

    protected $fillable = [
        'customer_id',
        'supplier_id',
        'recipient_phone',
        'recipient_name',
        'notification_type',
        'reference_type',
        'reference_id',
        'idempotency_key',
        'message',
        'status',
        'provider',
        'provider_message_id',
        'error_message',
        'payload',
        'response',
        'retry_count',
        'last_attempt_at',
        'sent_at',
        'created_by',
    ];

    protected $casts = [
        'payload' => 'array',
        'response' => 'array',
        'retry_count' => 'integer',
        'last_attempt_at' => 'datetime',
        'sent_at' => 'datetime',
    ];

    const STATUS_PENDING = 'PENDING';
    const STATUS_SENT = 'SENT';
    const STATUS_FAILED = 'FAILED';
    const STATUS_SIMULATED = 'SIMULATED';

    public function customer(): BelongsTo
    {
        return $this->belongsTo(Customer::class);
    }

    public function supplier(): BelongsTo
    {
        return $this->belongsTo(Supplier::class);
    }

    public function creator(): BelongsTo
    {
        return $this->belongsTo(User::class, 'created_by');
    }
}
