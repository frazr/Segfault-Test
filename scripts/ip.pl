#!/usr/bin/perl -w

sub create_timestamp{
        my ($timestamp) = @_;
        open my $fh, ">", $last_reload;
        print $fh $timestamp;
        close $fh;
}

sub last_reload{
        $last_reload = "/tmp/last_reload";
        my $epoch = time();

        if (!-e $last_reload) {
                open my $fh, ">>", $last_reload;
                close $fh;
        }

        open my $fh, "<", $last_reload;
        my $line = <$fh>;
        if (length $line)
        {
                chomp $line;
                if($line eq "")
                {
                        create_timestamp($epoch);
                }
                else
                {
                        $time_passed = $epoch - $line;
                        if ($time_passed > 10) {
                                create_timestamp($epoch);
                                close $fh;
                                return 0;
                        }
                }
        }
        else
        {
                create_timestamp($epoch);
        }
        close $fh;
        return 1;
}

$num_args = $#ARGV;
if ($num_args != 1) {
        print "Not enough inputs supplied. Exiting...\n";
        exit;
} else {
        $action=$ARGV[0];
        $ipaddr=$ARGV[1];


        if( $ipaddr =~ m/^(\d\d?\d?)\.(\d\d?\d?)\.(\d\d?\d?)\.(\d\d?\d?)$/ )
        {
                print("IP Address $ipaddr  -->  VALID FORMAT! \n");

                if($1 <= 255 && $2 <= 255 && $3 <= 255 && $4 <= 255)
                {
                        print("IP address:  $1.$2.$3.$4  -->  All octets within range\n");
                        if ($action eq 'ban')
                        {
                                print("Banning IP: $ipaddr\n");
                                $command = "echo \"deny $ipaddr;\" >> /data/etc/blocked_ips.conf";
                        } else {
                                print("Unbanning IP: $ipaddr\n");
                                $command = "sed -i \"/$ipaddr/d\" /data/etc/blocked_ips.conf"
                        }
			
			system($command);
			system('/etc/init.d/nginx reload');
                }
        }
        else
        {
                print("IP Address $ipaddr  -->  NOT IN VALID FORMAT! \n");
        }
}
