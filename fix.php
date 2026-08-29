<?php
$f = file_get_contents('lib/core/sync/sync_service.dart');
$f = preg_replace("/case 'CREATE_ORDER':.*case 'UPDATE_CUSTOMER':/s", "case 'CREATE_ORDER':
        final response = await api.client.post('/orders', data: entry.payload);
        return response.data;
      case 'UPDATE_ORDER':
        final response2 = await api.client.put('/orders/\${entry.entityId}', data: entry.payload);
        return response2.data;
      case 'UPDATE_CUSTOMER':", $f);
file_put_contents('lib/core/sync/sync_service.dart', $f);
