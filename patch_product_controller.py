import sys

with open('backend/app/Http/Controllers/Api/V1/ProductController.php', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace("use App\Models\Product;", "use App\Models\Product;\nuse App\Models\Warehouse;\nuse App\Models\WarehouseStock;")

target_store = "$product = Product::create($validated);"
replacement_store = """$product = Product::create($validated);
        
        $initial_stock = $request->input('initial_stock', 0);
        $warehouse = Warehouse::firstOrCreate(['name' => 'کۆگای سەرەکی'], ['location' => 'سەرەکی', 'is_active' => true]);
        WarehouseStock::create([
            'product_id' => $product->id,
            'warehouse_id' => $warehouse->id,
            'quantity' => $initial_stock
        ]);"""
content = content.replace(target_store, replacement_store)

target_update = "$product->update($validated);"
replacement_update = """$product->update($validated);

        if ($request->has('initial_stock')) {
            $initial_stock = $request->input('initial_stock');
            $warehouse = Warehouse::firstOrCreate(['name' => 'کۆگای سەرەکی'], ['location' => 'سەرەکی', 'is_active' => true]);
            $stock = WarehouseStock::firstOrNew([
                'product_id' => $product->id,
                'warehouse_id' => $warehouse->id
            ]);
            $stock->quantity = $initial_stock;
            $stock->save();
        }"""
content = content.replace(target_update, replacement_update)

with open('backend/app/Http/Controllers/Api/V1/ProductController.php', 'w', encoding='utf-8') as f:
    f.write(content)

print("Patched ProductController.php")
