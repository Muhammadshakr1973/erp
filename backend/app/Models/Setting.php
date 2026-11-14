<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Support\Facades\Cache;

class Setting extends Model
{
    use HasFactory;

    protected $fillable = ['key', 'value', 'updated_by'];

    protected $casts = [
        'value' => 'json',
    ];

    public function updater()
    {
        return $this->belongsTo(User::class, 'updated_by');
    }

    public static function getValue(string $key, $default = null): mixed
    {
        return Cache::rememberForever('setting_' . $key, function () use ($key, $default) {
            $setting = static::where('key', $key)->first();
            if (!$setting) {
                return $default;
            }

            $value = $setting->value;
            if ($value === null) {
                $raw = $setting->getRawOriginal('value');
                if ($raw !== null && $raw !== '') {
                    return $raw;
                }
                return $default;
            }

            return $value;
        });
    }

    public static function setValue(string $key, mixed $value, ?int $userId = null): void
    {
        static::updateOrCreate(['key' => $key], ['value' => $value, 'updated_by' => $userId]);
        Cache::forget('setting_' . $key);
    }
}
