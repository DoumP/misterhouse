# Category=MisterHouse

$v_reload_code = new  Voice_Cmd("{Reload,re load} code");
$v_reload_code-> set_info('Load new mh.ini, icon, and/or code changes');
if (state_now $v_reload_code) {
                                # Must be done before the user code eval
    push @Nextpass_Actions, \&read_code;
#   read_code();
#   $Run_Members{mh_control} = 2; # Reset, so the mh_temp.user_code decrement works
}

$v_read_tables = new Voice_Cmd 'Read table files';
read_table_files if said $v_read_tables;

$v_set_password = new  Voice_Cmd("Set the password");
if (said $v_set_password) {
    @ARGV = ();
    do "$Pgm_PathU/set_password";
}

$v_uptime = new  Voice_Cmd("What is your up time", 0);
$v_uptime-> set_info('Check how long the comuter and MisterHouse have been running');
$v_uptime-> set_authority('anyone');

if (said $v_uptime) {
    my $uptime_pgm      = &time_diff($Time_Startup_time, time);
    my $uptime_computer = &time_diff($Time_Boot_time, $Time);
#   speak("I was started on $Time_Startup\n");
    speak("I was started $uptime_pgm ago. The computer was booted $uptime_computer ago.");
}

                                # Control and monitor the http server
$v_http_control = new Voice_Cmd '[Open,Close,Restart,Check] the http server';
if ($state = said $v_http_control) {
#   print_log "${state}ing the http server";
    socket_open    'http' if $state eq 'Open';
    socket_close   'http' if $state eq 'Close';
    socket_restart 'http' if $state eq 'Restart';
}

                                # Check the http port frequently, so we can restart it if down.
$http_monitor   = new  Socket_Item(undef, undef, "$config_parms{http_server}:$config_parms{http_port}");
#f ((said $v_http_control eq 'Check') or new_minute 1) {
if ((said $v_http_control eq 'Check')) {
    unless (start $http_monitor) {
        my $msg = "The http server $config_parms{http_server}:$config_parms{http_port} is down.  Restarting";
        print_log $msg;
        display text => $msg, time => 0;
        socket_close 'http';    # Somehow this gets it going again?
        stop $http_monitor if active $http_monitor; # Need this?
    }
    else {
        print_log "The http server is up" if said $v_http_control;
        stop $http_monitor;
    }
}

        

$v_restart_mh = new Voice_Cmd 'Restart Mister House';
$v_restart_mh-> set_info('Restart mh.  This will only work if you are start mh with mh/bin/mhl');
&exit_pgm(1) if said $v_restart_mh;

if ($Startup and $Save{mh_exit} ne 'normal') {
    display "MisterHouse auto restarted: $Save{mh_exit}", 0;
}

$v_reboot = new  Voice_Cmd 'Reboot the computer';
$v_reboot-> set_info('Do this only if you really mean it!  Windows only');

if (said $v_reboot and $OS_win) {
#   if ($Info{OS_name} eq 'Win95') {
#        speak "Sorry, the reboot option does not work on Win95";
#   }
    if ($Info{OS_name} eq 'NT') {
        my $machine = $ENV{COMPUTERNAME};
        speak "The computer $machine will reboot in 1 minute.";
        Win32::InitiateSystemShutdown($machine, 'Rebooting in 1 minutes', 60, 1, 1);
        &exit_pgm;
    }
                                # In theory, either of these work for Win98/WinMe
    elsif ($Info{OS_name} eq 'WinMe') {
        speak "The house computer will reboot in 15 seconds";
        run 'start c:\\windows\\system\\runonce.exe -q';
        sleep 5;                # Give it a chance to get started
        &exit_pgm;
    }
    else {
        run 'rundll32.exe shell32.dll,SHExitWindowsEx 6 ';
        sleep 5;                # Give it a chance to get started
        &exit_pgm;
    }
}

#http://support.microsoft.com/support/kb/articles/q234/2/16.asp
#  rundll32.exe shell32.dll,SHExitWindowsEx n
#where n is one, or a combination of, the following numbers:
#0 - LOGOFF
#1 - SHUTDOWN
#2 - REBOOT
#4 - FORCE
#8 - POWEROFF
#The above options can be combined into one value to achieve different results. 
#For example, to restart Windows forcefully, without querying any running programs, use the following command line: 
#rundll32.exe shell32.dll,SHExitWindowsEx 6 

#$v_reboot_abort = new  Voice_Cmd("Abort the reboot");
#if (said $v_reboot_abort and $OS_win) {
#  Win32::AbortSystemShutdown('HOUSE');
#  speak("OK, the reboot has been aborted.");
#}

$v_debug = new  Voice_Cmd("Set debug to [X10,serial,http,misc,startup,socket,off]");
$v_debug-> set_info('Controls what kind of debug is printed to the console');
if ($state = said $v_debug) {
    $config_parms{debug} = $state;
    $config_parms{debug} = 0 if $state eq 'off';
    speak "Debug has been turned $state";
}

$v_mode = new  Voice_Cmd("Put house in [normal,mute,offline] mode");
$v_mode-> set_info('mute mode disables all speech and sound.  offline disables all serial control');
if ($state = said $v_mode) {
    $Save{mode} = $state;
    speak "The house is now in $state mode.";
    print_log "The house is now in $state mode.";
}

$v_mode_toggle = new  Voice_Cmd("Toggle the house mode");
if (said $v_mode_toggle) {
    if ($Save{mode} eq 'mute') {
        $Save{mode} = 'offline';
    }
    elsif ($Save{mode} eq 'offline') {
        $Save{mode} = 'normal';
    }
    else {
        $Save{mode} = 'mute';
    }
                                # mode => force cause speech even in mute or offline mode
    &speak(mode => 'unmuted', rooms => 'all', text => "Now in $Save{mode} mode");
}


                                # Search for strings in user code
#&tk_entry('Code Search', \$Save{mh_code_search}, 'Debug flag', \$config_parms{debug});

$search_code_string = new Generic_Item; # Set from web menu mh/web/ia5/house/search.shtml

if ($temp = quotemeta $Tk_results{'Code Search'} or
    $temp = state_now $search_code_string) {

    undef $Tk_results{'Code Search'};
    print "Searching for code $temp";
    my ($results, $count, %files);
    $count = 0;
    for my $file (sort keys %User_Code) {
        my $n = 0;
        for (@{$User_Code{$file}}) {
            $n++;
            if (/$temp/i) {
                $count++;
                $results .= "\nFile: $file:\n------------------------------\n" unless $files{$file}++;
                $results .= sprintf("%4d: %s", $n, $_);
            }
        }
    }
    print_log "Found $count matches";
    $results = "Found $count matches\n" . $results;
    display $results, 60, 'Code Search Results', 'fixed' if $count;
}


                                # Create a list by X10 Addresses
$v_list_x10_items = new Voice_Cmd 'List {X 10,X10} items';
$v_list_x10_items-> set_info('Generates a report fo all X10 items, sorted by device code');
if (said $v_list_x10_items) {
    print_log "Listing X10 items";
    my @object_list = (&list_objects_by_type('X10_Item'),
                       &list_objects_by_type('X10_Appliance'), 
                       &list_objects_by_type('X10_Garage_Door'));
    my @objects = map{&get_object_by_name($_)} @object_list;
    my $results;
    for my $object (sort {$a->{x10_id} cmp $b->{x10_id}} @objects) {
        $results .= sprintf("Address:%-2s  File:%-15s  Object:%-30s State:%s\n",
                            substr($object->{x10_id}, 1), $object->{filename}, $object->{object_name}, $object->{state});
    }
    display $results, 60, 'X10 Items', 'fixed';
}

                                # Create a list by Serial States
$v_list_serial_items = new Voice_Cmd 'List serial items';
$v_list_serial_items-> set_info('Generates a report of all Serial_Items, sorted by serial state');
if (said $v_list_serial_items) {
    print_log "Listing serial items";
    my @object_list = &list_objects_by_type('Serial_Item');
    my @objects = map{&get_object_by_name($_)} @object_list;
    my @results;

                                # Sort object by the first id
    for my $object (@objects) {
#        my ($first_id, $states);
        for my $id (sort keys %{$$object{state_by_id}}) {
            push @results, sprintf("ID:%-5s File:%-15s Object:%-15s states: %s",
                                   $id, $object->{filename}, $object->{object_name}, $$object{state_by_id}{$id});
#            $first_id = $id unless $first_id;
#            $states .= "$id=$$object{state_by_id}{$id}, ";
        }
#        push @results, sprintf("ID:%-5s File:%-15s Object:%-15s states: %s",
#                               $first_id, $object->{filename}, $object->{object_name}, $states);
    }
    my $results = join "\n", sort @results;
    display $results, 60, 'Serial Items', 'fixed';
}


                                # Echo serial matches
&Serial_match_add_hook(\&serial_match_log) if $Reload;

sub serial_match_log {
    my ($ref, $state, $event) = @_;
    return unless $event =~ /^X/; # Echo only X10 events
    my $name = substr $$ref{object_name}, 1;
    print_log "$event: $name $state" if $config_parms{x10_errata} > 1 and !$$ref{no_log};
}
 
                                # Allow for keyboard control
if ($Keyboard) {    
    if ($Keyboard eq 'F1') {
        print "Key F1 pressed.  Reloading code\n";
                                # Must be done before the user code eval
        push @Nextpass_Actions, \&read_code;
    }
    elsif ($Keyboard eq 'F2') {
        print "Key F2 pressed.  Toggle pause mode.\n";
        &toggle_pause;          # Leaving pause mode is still done in mh code
    }
    elsif ($Keyboard eq 'F3') {
        print "Key F3 pressed.  Exiting\n";
        &exit_pgm;
    }
    elsif ($Keyboard eq 'F4') {
        &toggle_debug;
    }
    elsif ($Keyboard eq 'F5') {
        &toggle_log;
    }
    elsif ($Keyboard) {
        print "key press: $Keyboard\n" if $config_parms{debug} eq 'misc';
    }
}

                                # Monitor if web password was set or unset
speak 'rooms=all Web password was just set' if $Cookies{password_was_set};
speak 'rooms=all Notice, an invalid Web password was just specified' if $Cookies{password_was_not_set};


                                # Those with ups devices can set this seperatly
                                # Those without a CM11 ... this will not hurt any
$Power_Supply = new Generic_Item;

if ($ControlX10::CM11::POWER_RESET) {
    $ControlX10::CM11::POWER_RESET = 0;
    set $Power_Supply 'Restored';
    print_log 'Power reset detected';
    display time => 0, text => "Detected a CM11 power reset";
}

                                # Set back to normal 1 pass after restored
if (state_now $Power_Supply eq 'Restored') {
    print_log 'Power has been restored';
    set $Power_Supply 'Normal';
}


                                # Repeat last spoken
$v_repeat_last_spoken = new Voice_Cmd '{Repeat your last message,What did you say}', '';
if (said $v_repeat_last_spoken) {
    ($temp = $Speak_Log[0]) =~ s/^.+?: //s; # Remove time/date/status portion of log entry
    speak "I said $temp";
}

$v_clear_cache = new Voice_Cmd 'Clear the web cache directory', '';
$v_clear_cache-> set_info('Delete all the auto-generated .jpg files in mh/web/cache');
if (said $v_clear_cache) {
    my $cmd = ($OS_win) ? 'del' : 'rm';
    $cmd .= " $config_parms{html_dir}/cache/*.jpg";
    $cmd =~ s|/|\\|g if $OS_win;
    system $cmd;
    print_log "Ran: $cmd";
}

    