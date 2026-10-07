<?php

namespace App\Providers;

use Illuminate\Support\ServiceProvider;

class AppServiceProvider extends ServiceProvider
{
    /**
     * Register any application services.
     */
    public function register(): void
    {
        //
    }

    /**
     * Bootstrap any application services.
     */
    public function boot(): void
    {
        try {
            if (\Illuminate\Support\Facades\Schema::hasTable('customers')) {
                $exists = \Illuminate\Support\Facades\DB::table('customers')->where('id', 0)->exists();
                if (!$exists) {
                    $defaultRoute = \Illuminate\Support\Facades\DB::table('routes')->first();
                    if (!$defaultRoute) {
                        $defaultRouteId = \Illuminate\Support\Facades\DB::table('routes')->insertGetId([
                            'name' => 'گشتی',
                            'color' => '#888888',
                            'is_active' => 1,
                            'created_at' => now(),
                            'updated_at' => now(),
                        ]);
                    } else {
                        $defaultRouteId = $defaultRoute->id;
                    }

                    \Illuminate\Support\Facades\DB::statement('SET SESSION sql_mode = "NO_AUTO_VALUE_ON_ZERO";');
                    \Illuminate\Support\Facades\DB::table('customers')->insert([
                        'id' => 0,
                        'name' => 'کڕیاری کاتی (بێ ناو)',
                        'phone' => '00000000000',
                        'customer_name' => null,
                        'route_id' => $defaultRouteId,
                        'price_type' => 'N3',
                        'current_balance' => 0,
                        'is_active' => 1,
                        'created_by' => null,
                        'created_at' => now(),
                        'updated_at' => now(),
                    ]);
                }
            }
        } catch (\Throwable $e) {
            // Silence failure if DB tables aren't fully migrated yet
        }
    }
}
