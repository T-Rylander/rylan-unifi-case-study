<?php
// osTicket plugin: Hooks ticket.created ? POST to AI triage (VLAN 10)
require_once INCLUDE_DIR . ''class.signal.php'';
Signal::connect(''ticket.created'', function ($ticket) {
    $data = [
        ''text'' => $ticket->getSubject() . '' '' . $ticket->getMessage(),
        ''vlan_source'' => $_SERVER[''HTTP_X_VLAN''] ?? ''30'',  // From UniFi client tag
        ''user_role'' => $ticket->getStaff() ? ''staff'' : ''user''
    ];
    $ch = curl_init(''http://10.0.10.60:8000/triage'');
    curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($data));
    curl_setopt($ch, CURLOPT_HTTPHEADER, [''Content-Type: application/json'', ''X-API-Key: '' . getenv(''OSTICKET_KEY'')]);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    $response = curl_exec($ch);
    curl_close($ch);
    if (json_decode($response, true)[ ''action'' ] === ''auto-close'') {
        $ticket->setStatus(5);  // Closed
        $ticket->save();
    }
});
?>
