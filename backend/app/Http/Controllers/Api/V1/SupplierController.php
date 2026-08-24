<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use Illuminate\Support\Facades\DB;

class SupplierController extends Controller
{
    public function index()
    {
        $suppliers = DB::table('suppliers')->whereNull('deleted_at')->get();
        return response()->json([
            'message' => 'لیستی سەپڵایەرەکان',
            'data' => $suppliers
        ]);
    }
}
