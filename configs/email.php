<?php
return array(
    'default' => array(
        // Using 'native' type - emails will silently fail if mail server not configured
        // This prevents 503 errors on user registration
        'type'        => 'native',

        // SMTP settings (not used with 'native' type)
        'hostname'    => 'localhost',
        'port'        => '25',
        'username'    => null,
        'password'    => null,
        'encryption'  => null,
        'timeout'     => 5,

        'sendmail_command' => null,
        'mail_parameters'  => "-f%s"
    )
);
