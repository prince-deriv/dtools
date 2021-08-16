#!/etc/rmg/bin/perl
package t::Validation::Transaction::Payment::Deposit;
package BOM::Test::Helper::FinancialAssessment;

use strict;
use warnings;

#############################
#Guideline to create account with script create_account.pl

#perl create_account.pl <email> <broker_code> <country_residence> <currency> --<other option>

#default: Normal account with balance perl create_account.pl test@email.com CR id USD

#With PA: perl create_account.pl test@email.com CR id USD --pa

#No balance/deposit perl create_account.pl test@email.com CR id USD --no_deposit

#No currency set perl create_account.pl test@email.com CR id USD --no_currency

#Copier account perl create_account.pl test@email.com CR id USD --copier
#############################

use Test::More;
use Test::Exception;
use Test::MockObject::Extends;

use BOM::User;
use BOM::User::Client;
#use BOM::User::Client::Payments;
use BOM::User::Password;
use BOM::Platform::Client::IDAuthentication;
use Getopt::Long qw(GetOptions);
use Locale::Country::Extra;

use BOM::RPC::v3::Accounts;
use BOM::Test::Helper::FinancialAssessment;

use Crypt::CBC;
use Crypt::NamedKeys;
Crypt::NamedKeys::keyfile '/etc/rmg/aes_keys.yml';

my $email    = $ARGV[0] or die "Email is required";
my $broker_code = $ARGV[1] or die "Broker code is required";
my $residence = $ARGV[2] or die "Residence is required";
my $currency = $ARGV[3] or die "Currency is required";
my $has_payment_agent;
my $no_deposit;
my $no_currency;
my $is_copier;
my $is_advertiser;
my $allow_copier = 1;
my $countries = Locale::Country::Extra->new();


GetOptions(
    'pa' => \$has_payment_agent,
    'no_deposit' => \$no_deposit,
    'no_currency' => \$no_currency,
    'copier' => \$is_copier,
    'advertiser' => \$is_advertiser,
);

if ($is_copier) {
    $allow_copier = 0;
};
    
my @randstr = ("A".."Z", "a".."z");
my $randstr;
$randstr .= $randstr[rand @randstr] for 1..3;

my @randnum = ("0".."9");
my $randnum;
$randnum .= $randnum[rand @randnum] for 1..5;

my $name = $email;
$name =~ s/\@.*//;
$name =~ s/[^a-zA-Z,]//g;

my $phone = "+624175".$randnum;
my $last_name = $name.$randstr;

my $hash_pwd = BOM::User::Password::hashpw("Abcd1234");
my $secret_answer = Crypt::NamedKeys->new(keyname => 'client_secret_answer')->encrypt_payload(data => "blah");

my $user = BOM::User->create(
    email    => $email,
    password => $hash_pwd,
    email_verified => 1,
    email_consent => 1
);

my $client_details = {
    broker_code     => $broker_code,
    residence       => $residence,
    client_password => 'x',
    last_name       => $last_name,
    first_name      => 'QA script',
    email           => $email,
    salutation      => 'Ms',
    address_line_1  => 'ADDR 1',
    address_city    => 'Cyber',
    phone           => $phone,
    secret_question => "Mother's maiden name",
    secret_answer   => $secret_answer,
    place_of_birth  => $residence,
    account_opening_reason => 'Speculative',
    date_of_birth => '1990-01-01',
    source          => 1098,
    non_pep_declaration_time => time
};

my $deposit_amount = 10000;
my @fiat = ( "USD", "EUR", "AUD", "GBP" );

# Deposit 10 for crypto account
if (not grep $_ eq $currency, @fiat) {
      $deposit_amount = 10;
}

my %deposit = (
    currency     => 'USD',
    amount       => 10_000,
    remark       => 'here is money (account created by script)',
    payment_type => 'free_gift'
);

# create virtual account
sub create_virtual{
    my $vrtc_client = $user->create_client(
            broker_code        => 'VRTC',
            first_name         => '',
            email              => $email,
            last_name          => '',
            password           => 'x',
            residence          => $residence,
            address_line_1     => '',
            address_line_2     => '',
            address_city       => '',
            address_state      => '',
            address_postcode   => '',
            phone              => '',
            secret_question    => '',
            secret_answer      => ''
    );

    $vrtc_client->email($email);
    $vrtc_client->set_default_account('USD');
    $vrtc_client->payment_free_gift(%deposit, currency => 'USD', amount => 10_000);
    $vrtc_client->save();

    my $broker_code = "VRTC";
    print_login_id($vrtc_client);
    create_api_token($vrtc_client);

}

# create CR account
sub create_cr{
    my $cr_client = $user->create_client(
        %$client_details,
        address_postcode => '47120',
        # allow copier
        allow_copiers => $allow_copier,

    );

    $cr_client->email($email);
    if (!($no_currency)) {
        set_currency($cr_client);
    };
    if (!($no_currency) && !($no_deposit)) {
        deposit($cr_client);
    };
    approve_tnc($cr_client);

    $cr_client->save();
   
    create_api_token($cr_client);
 
    if ($has_payment_agent) {
        payment_agent($cr_client);
    };
       
    if ($is_advertiser) {
        $cr_client->status->set('age_verification', 'system', 'verified using QA script');
        $cr_client->p2p_advertiser_create(name => 'client '.$cr_client->loginid);
        $cr_client->p2p_advertiser_update(
            is_listed   => 1,
            is_approved => 1);
            
        $cr_client->p2p_advert_create(
        account_currency => 'USD',
        local_currency   => $cr_client->local_currency,
        amount           => 100,
        rate             => 14500,
        type             => 'buy',
        expiry           => 2 * 60 * 60,
        min_order_amount => 10,
        max_order_amount => 100,
        payment_method   => 'bank_transfer',
        description      => 'Created by script. Please call me 02203400',
        country          => $cr_client->residence,
        );
    
        $cr_client->p2p_advert_create(
        account_currency => 'USD',
        local_currency   => $cr_client->local_currency,
        amount           => 100,
        rate             => 13500,
        type             => 'sell',
        expiry           => 2 * 60 * 60,
        min_order_amount => 10,
        max_order_amount => 100,
        payment_method   => 'bank_transfer',
        payment_info     => 'Transfer to account 000-1111',
        contact_info     => 'Created by script. Please call me 02203400',
        description      => 'Created by script. Please call me 02203400',
        country          => $cr_client->residence,
        );
    
    };

    print_login_id($cr_client);
    print_residence($cr_client);

}


# create MX account
sub create_mx{
    my $mx_client = $user->create_client(
        %$client_details,
        citizen          => 'gb',
        address_postcode => '47120',
    );

    $mx_client->email($email);
    if (!($no_currency)) {
        set_currency($mx_client);
    };
    if (!($no_currency) && !($no_deposit)) {
        deposit($mx_client);
    };
    approve_tnc($mx_client);
    $mx_client->save();
    $mx_client->status->setnx('unwelcome', 'system', 'FailedExperian - Experian request failed and will be attempted again within 1 hour.');
    $mx_client->status->set('max_turnover_limit_not_set', 'system', 'new GB client or MLT client - have to set turnover limit') ;
    $mx_client->status->setnx('proveid_pending', 'system', 'Experian request failed and will be attempted again within 1 hour.');
    $mx_client->status->setnx('proveid_requested', 'system', 'ProveID request has been made for this account.');

    print_login_id($mx_client);
    create_api_token($mx_client);
    print_residence($mx_client);

}

# create MF account
sub create_mf{
    my $mf_client = $user->create_client(
        %$client_details,
        broker_code     => 'MF',
        tax_residence   => 'es',
        tax_identification_number => '111-222-333',
        citizen         => 'es',
    );

    $mf_client->email($email);
    if (!($no_currency)) {
        set_currency($mf_client);
    };
    if (!($no_currency) && !($no_deposit)) {
        deposit($mf_client);
    };
    approve_tnc($mf_client);
    set_financial_assessment($mf_client);
    $mf_client->save();

    print_login_id($mf_client);
    create_api_token($mf_client);
    print_residence($mf_client);
}

sub create_mlt{
    my $mlt_client = $user->create_client(
        %$client_details,
        broker_code     => 'MLT',
        citizen         => 'at',
    );

    $mlt_client->email($email);
    if (!($no_currency)) {
        set_currency($mlt_client);
    };
    if (!($no_currency) && !($no_deposit)) {
        deposit($mlt_client);
    };
    approve_tnc($mlt_client);
    $mlt_client->save();

    print_login_id($mlt_client);
    create_api_token($mlt_client);
    print_residence($mlt_client);

    return $mlt_client;
}

sub set_currency{
    my $client = shift;
    $client->set_default_account($currency);
    return $client;
}

sub deposit{
    my $client = shift;
    $client->payment_free_gift(%deposit, currency => $currency, amount => $deposit_amount);
    return $client;
}

sub approve_tnc{
    my $client = shift;
    $client->user->set_tnc_approval;
    return $client;
}

sub maltainvest_fa {
    my %data = (
        "forex_trading_experience"             => "0-1 year",                                     
        "forex_trading_frequency"              => "0-5 transactions in the past 12 months",           
        "binary_options_trading_experience"    => "0-1 year",                                        
        "binary_options_trading_frequency"     => "0-5 transactions in the past 12 months",    
        "cfd_trading_experience"               => "0-1 year",                                        
        "cfd_trading_frequency"                => "0-5 transactions in the past 12 months",           
        "other_instruments_trading_experience" => "0-1 year",                                     
        "other_instruments_trading_frequency"  => "0-5 transactions in the past 12 months",          
        "employment_industry"                  => "Health",                                          
        "education_level"                      => "Secondary",                                        
        "income_source"                        => "Self-Employed",                                    
        "net_income"                           => '$25,000 - $50,000',                                
        "estimated_worth"                      => '$100,000 - $250,000',                              
        "occupation"                           => 'Managers',                                         
        "employment_status"                    => "Self-Employed",                                    
        "source_of_wealth"                     => "Company Ownership",                                
        "account_turnover"                     => 'Less than $25,000',                                
    );

    return encode_json_utf8(\%data);
}

sub set_financial_assessment{
    my $client = shift;
    $client->financial_assessment({data => maltainvest_fa()});
    $client->status->set('financial_risk_approval', 'SYSTEM', 'Client accepted financial risk disclosure');

}

sub create_api_token{
    my $client = shift;
    my $loginid = $client->loginid;
    my $log_broker_code = $loginid;
    $log_broker_code =~ s/\d//g;
    my $res = BOM::RPC::v3::Accounts::api_token({
            client => $client,
            args   => {
                new_token        => 'Created by script',
                new_token_scopes => ['read', 'trade','payments','admin']
            },
        });

    my $token = $res->{tokens}->[0]->{token};
    print "$log_broker_code api token: $token
";
}

sub payment_agent{

  my $client = shift;
  my $loginid = $client->loginid;
  my $currency = $client->currency;
  my $residence = $client->residence;
  my $pa_client = $client;
  
  $client->set_authentication('ID_DOCUMENT', {status => 'pass'});

  $pa_client->payment_agent({
      payment_agent_name    => 'Payment Agent of '.$loginid.' (Created from Script)',
      url                   => 'http://www.MyPAMyAdventure.com/',
      email                 => 'MyPaScript@example.com',
      phone                 => '+12345678',
      information           => 'Test Info',
      summary               => 'Test Summary',
      commission_deposit    => 0,
      commission_withdrawal => 0,
      is_authenticated      => 't',
      currency_code         => $currency,
      target_country        => $residence,
      min_withdrawal        => '10',
      max_withdrawal        => '2000',

  });
  $pa_client->save;
}

sub print_login_id{
    my $client = shift;
    my $loginid = $client->loginid;
    my $log_broker_code = $loginid;
    $log_broker_code =~ s/\d//g;

    print "$log_broker_code loginid: $loginid
";
}

sub print_residence{
    my $client = shift;
    my $client_residence = $countries->country_from_code($client->residence);
    my $loginid = $client->loginid;
    my $log_broker_code = $loginid;
    $log_broker_code =~ s/\d//g;

    print "Residence: $client_residence
";
}

#------------------------------------------------------

# create VRTC account
if ($broker_code eq "VRTC"){
    create_virtual();
}

# create CR account
if ($broker_code eq "CR"){
    create_virtual();
    create_cr();
}

# create MX account
elsif ($broker_code eq "MX"){
    create_virtual();
    create_mx();
}

# create MF account
elsif ($broker_code eq "MF"){
    create_virtual();
    create_mf();
}

# create MLT MF account
elsif ($broker_code eq "MLT"){
    create_virtual();
    create_mlt();
    if ($residence ne "be"){
        create_mf();
    };
}

1;




