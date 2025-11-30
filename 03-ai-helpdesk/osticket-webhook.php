<?php
/**
 * osTicket Webhook Plugin Stub
 * Triggers AI triage engine on new ticket creation.
 *
 * Place this file under osTicket include/plugins and register as a plugin.
 * Requires OSTICKET_API_KEY configured on the triage engine side.
 */

if (!defined('OSTICKETINC')) die('Access Denied');

class RylanAiTriagePlugin extends Plugin {
    var $config_class = 'RylanAiTriageConfig';

    function bootstrap() {
        Signal::connect('ticket.created', function($ticket) {
            try {
                $data = array(
                    'ticket_id' => $ticket->getId(),
                    'subject'   => $ticket->getSubject(),
                    'body'      => (string)$ticket->getLastMessage(),
                    'vlan_source'=> '30', // Trusted devices VLAN by default
                    'user_role' => 'employee'
                );

                $this->postJson($this->getConfig()->get('triage_endpoint'), $data, $this->getConfig()->get('api_key'));
            } catch (Exception $e) {
                error_log('AI Triage webhook error: ' . $e->getMessage());
            }
        });
    }

    private function postJson($url, $data, $apiKey) {
        $ch = curl_init($url);
        $payload = json_encode($data);
        curl_setopt($ch, CURLOPT_POST, true);
        curl_setopt($ch, CURLOPT_POSTFIELDS, $payload);
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
        curl_setopt($ch, CURLOPT_HTTPHEADER, array(
            'Content-Type: application/json',
            'X-API-Key: ' . $apiKey,
        ));
        $response = curl_exec($ch);
        if ($response === false) {
            throw new Exception('cURL error: ' . curl_error($ch));
        }
        curl_close($ch);
    }
}

class RylanAiTriageConfig extends PluginConfig {
    function getOptions() {
        return array(
            'triage_endpoint' => new TextboxField(array(
                'label' => __('Triage Endpoint URL'),
                'required' => true,
                'default' => 'http://10.0.10.60:8000/triage'
            )),
            'api_key' => new TextboxField(array(
                'label' => __('API Key'),
                'required' => true,
                'default' => ''
            )),
        );
    }
}
