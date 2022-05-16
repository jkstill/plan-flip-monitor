package Mail::Simple;

# Mail::Sendmail by Milivoj Ivkovic <mi\x40alma.ch>
# see embedded POD documentation after __END__
# or http://alma.ch/perl/mail.html

=head1 NAME

 Mail::Simple - Very simple email module

 It works with ssmtp or sendmail.
 
 If sendmail is found, then it is used.
 
 If ssmtp is not found, then sendmail is used.

 An error is raised if neither is available

=cut

require 5.006;

our $VERSION  = "0.01";

use strict;
use warnings;
use POSIX qw(strftime);

use Exporter qw(import);

our @ISA= qw(Exporter);
our @EXPORT = qw(&mailit);

sub getMailer {
	my @paths2chk=qw(/usr/sbin /sbin /bin /usr/sgin);
	my @mailers=qw(ssmtp sendmail);

	my $mailProgram='';

	foreach my $mailer (@mailers) {
		foreach my $dir (@paths2chk) {
			my $mailerPath="$dir/$mailer";
			#print "mailpath: $mailerPath\n";
			if ( -x $mailerPath ) {
				$mailProgram = $mailerPath;
				#print "!! set mailer: $mailProgram\n";
				last;
			}
		}
		last if $mailProgram;
	}

	return $mailProgram;
}

sub mailit {

	my ( $to, $from, $subject, $message ) = @_;

	my $mailProgram = getMailer();

	$message .= "\n" . strftime "%a %b %e %H:%M:%S %Y", localtime;

	unless ( $mailProgram ) {
		warn "mailer not found!\n" ;
		return 0;
	}

	#print "mailer: $mailProgram\n";

	open(MAIL, "|$mailProgram -t");

	# Email Header
	eval {
		print MAIL "To: $to\n";
		print MAIL "From: $from\n";
		print MAIL "Subject: $subject\n\n";
		# Email Body
		print MAIL $message;

		close(MAIL);
	};

	if ($@) {
		warn "Email Error: $@\n";
		return 0;
	} else {
		return 1;
	}

}
