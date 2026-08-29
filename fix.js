const fs = require('fs');
let text = fs.readFileSync('lib/core/sync/sync_service.dart', 'utf8');
text = text.replace(/case 'CREATE_ORDER':[\s\S]*?case 'UPDATE_CUSTOMER':/, `case 'CREATE_ORDER':
        final response = await api.client.post('/orders', data: entry.payload);
        return response.data;
      case 'UPDATE_ORDER':
        final response2 = await api.client.put('/orders/\${entry.entityId}', data: entry.payload);
        return response2.data;
      case 'UPDATE_CUSTOMER':`);
fs.writeFileSync('lib/core/sync/sync_service.dart', text);
