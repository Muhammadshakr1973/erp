<?php
namespace Database\Factories;

use App\Models\Role;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;

class UserFactory extends Factory
{
    protected $model = User::class;

    public function definition(): array
    {
        return [
            'name' => fake()->name(),
            'email' => fake()->unique()->safeEmail(),
            'email_verified_at' => now(),
            'password' => Hash::make('password'),
            'remember_token' => Str::random(10),
            // فێڵدە زیادکراوەکان بۆ V6.1
            'phone' => fake()->unique()->phoneNumber(),
            'role_id' => Role::first()?->id ?? null,
            'commission_rate' => 0,
            'barcode' => null,
            'is_active' => true,
            'last_login_at' => null,
            'created_by' => null,
        ];
    }

    public function unverified(): static
    {
        return $this->state(fn (array $attributes) => [
            'email_verified_at' => null,
        ]);
    }

    public function owner(): static
    {
        return $this->state(fn (array $attributes) => [
            'role_id' => Role::where('name', Role::OWNER)->first()?->id,
            'is_active' => true,
        ]);
    }

    public function admin(): static
    {
        return $this->state(fn (array $attributes) => [
            'role_id' => Role::where('name', Role::ADMIN)->first()?->id,
            'is_active' => true,
        ]);
    }

    public function salesman(): static
    {
        return $this->state(fn (array $attributes) => [
            'role_id' => Role::where('name', Role::SALESMAN)->first()?->id,
            'commission_rate' => fake()->numberBetween(5, 15),
            'barcode' => 'SM-'.fake()->unique()->numberBetween(1000, 9999),
            'is_active' => true,
        ]);
    }
}
