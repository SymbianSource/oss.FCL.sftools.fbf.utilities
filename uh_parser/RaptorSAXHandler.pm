# Copyright (c) 2009 Symbian Foundation Ltd
# This component and the accompanying materials are made available
# under the terms of the License "Eclipse Public License v1.0"
# which accompanies this distribution, and is available
# at the URL "http://www.eclipse.org/legal/epl-v10.html".
#
# Initial Contributors:
# Symbian Foundation Ltd - initial contribution.
#
# Contributors:
# Dario Sestito <darios@symbian.org>
#
# Description:
# SAX Handler for the Raptor log

package RaptorSAXHandler;
use base qw(XML::SAX::Base);

sub new
{
    my ($type) = @_;
    
    return bless {}, $type;
}

sub add_observer
{
	my ($self, $name, $initialstatus) = @_;
	
	$self->{observers} = {} if (!defined $self->{observers});
	
	$self->{observers}->{$name} = $initialstatus;
}

sub start_document
{
	my ($self, $doc) = @_;
	# process document start event
	
	#print "start_document\n";
}
  
sub start_element
{
	my ($self, $el) = @_;
	# process element start event
	
	my $tagname = $el->{LocalName};
	
	#print "start_element($tagname)\n";
	
	for my $observer (keys %{$self->{observers}})
	{
		#print "processing observer $observer: $self->{observers}->{$observer} $self->{observers}->{$observer}->{name}\n";
		#for (keys %{$self->{observers}->{$observer}->{next_status}}) {print "$_\n";}
		
		if (defined $self->{observers}->{$observer}->{next_status}->{$tagname})
		{
			#print "processing observer $observer\n";
			my $oldstatus = $self->{observers}->{$observer};
			$self->{observers}->{$observer} = $self->{observers}->{$observer}->{next_status}->{$tagname};
			#print "$observer: status is now $self->{observers}->{$observer}->{name}\n";
			$self->{observers}->{$observer}->{next_status}->{$tagname} = $oldstatus;
			&{$self->{observers}->{$observer}->{on_start}}($el) if (defined $self->{observers}->{$observer}->{on_start});
		}
		elsif (defined $self->{observers}->{$observer}->{next_status}->{'?default?'})
		{
			#print "processing observer $observer\n";
			#print "changing to default status\n";
			my $oldstatus = $self->{observers}->{$observer};
			$self->{observers}->{$observer} = $self->{observers}->{$observer}->{next_status}->{'?default?'};
			#print "status is now ?default?\n";
			$self->{observers}->{$observer}->{next_status}->{$tagname} = $oldstatus;
			&{$self->{observers}->{$observer}->{on_start}}($el) if (defined $self->{observers}->{$observer}->{on_start});
		}
	}
}

sub end_element
{
	my ($self, $el) = @_;
	# process element start event
	
	my $tagname = $el->{LocalName};
	
	#print "end_element($tagname)\n";
	
	for my $observer (keys %{$self->{observers}})
	{
		if (defined $self->{observers}->{$observer}->{next_status}->{$tagname})
		{
			&{$self->{observers}->{$observer}->{on_end}}($el) if (defined $self->{observers}->{$observer}->{on_end});
			$self->{observers}->{$observer} = $self->{observers}->{$observer}->{next_status}->{$tagname};
			#print "status is now $self->{observers}->{$observer}->{name}\n";
		}
	}
}

sub characters
{
	my ($self, $ch) = @_;
	
	for my $observer (keys %{$self->{observers}})
	{
		&{$self->{observers}->{$observer}->{on_chars}}($ch) if (defined $self->{observers}->{$observer}->{on_chars});
	}
}

1;
