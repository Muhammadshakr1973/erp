<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Factories\HasFactory;

class SyncLog extends Model
{
    use HasFactory;
    protected $fillable = ['user_id', 'device_id', 'sync_type', 'table_name', 'records_synced', 'status', 'error_message', 'started_at', 'completed_at'];
    protected $casts = ['started_at' => 'datetime', 'completed_at' => 'datetime'];
    const TYPE_PUSH = 'push';
    const TYPE_PULL = 'pull';
    const STATUS_SUCCESS = 'success';
    const STATUS_FAILED = 'failed';
    public function user()
    {
        return $this->belongsTo(User::class);
    }
}
