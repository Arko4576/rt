#$Header$

package RT::Queue;
use RT::Record;
@ISA= qw(RT::Record);

# {{{ sub new 
sub new  {
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $self  = {};
  bless ($self, $class);
  $self->{'table'} = "Queues";
  $self->_Init(@_);
  return ($self);
}
# }}}

# {{{ sub _Accessible 
sub _Accessible  {
  my $self = shift;
  my %Cols = ( QueueId => 'read/write',
	       CorrespondAddress => 'read/write',
	       Description => 'read/write',
	       CommentAddress =>  'read/write',
	       InitialPriority =>  'read/write',
	       FinalPriority =>  'read/write',
	       DefaultDueIn =>  'read/write'
	     );
  return($self->SUPER::_Accessible(@_, %Cols));
}
# }}}

# {{{ sub Create
=head2 Create

Create takes the name of the new queue 
If you pass the ACL check, it creates the queue and returns its queue id.

=cut

sub Create  {
  my $self = shift;
  my %args = (@_); 
  
  #Check them ACLs
  return (0, "No permission to create queues") unless ($self->CurrentUserHasRight('CreateQueue'));
  

  my $id = $self->SUPER::Create(QueueId => $args{'QueueId'});
  $self->LoadById($id);
  return ($id, "Queue $id created");
}
# }}}

# {{{ sub Delete 

=head2 Delete

Delete this queue. takes a single argument which is either a queue id
or a queue object. All tickets in this queue will be moved to the queue
passed in

=cut

sub Delete  {
  my $self = shift;
  my $newqueue = shift;
 # this function needs to move all requests into some other queue!
  my ($query_string,$update_clause);
  
  die ("Queue->Delete not implemented yet");
  
      return(0, "You do not have the privileges to delete queues")
	unless ($self->CurrentUserHasRight('DeleteQueue'));
	  
  #TODO:  DO ALL THESE
  #Find all the tickets in this queue.
  #Go through the tickets and change their queue to $newqueue
  #Blow away all of the queue acls for this queue.
  #Remove the queue object
  return (1, "Queue $self->QueueId deleted.");
    
}

# }}}

# {{{ sub Load 
sub Load  {
  my $self = shift;
  
  my $identifier = shift;
  if (!$identifier) {
    return (undef);
  }	    

  if ($identifier !~ /\D/) {
    return($self->SUPER::LoadById($identifier));
  }
  else {
    return($self->LoadByCol("QueueId", $identifier));
  }

}
# }}}

# {{{ sub Watchers

=head2

Watchers returns a Watchers object preloaded with this ticket\'s watchers.

=cut

sub Watchers {
  my $self = shift;
  
  unless ($self->CurrentUserHasRight('Explore')) {
    return (0, "Permission Denied");
  }

  if (! defined ($self->{'Watchers'}) 
      || $self->{'Watchers'}->{is_modified}) {
    require RT::Watchers;
    $self->{'Watchers'} =RT::Watchers->new($self->CurrentUser);
    $self->{'Watchers'}->LimitToTicket($self->id);

  }
  return($self->{'Watchers'});
  
}
# }}}

# {{{ a set of  [foo]AsString subs that will return the various sorts of watchers for a ticket/queue as a comma delineated string

=head2 WatchersAsString

WatchersAsString ...

=item B<Takes>

=item I<nothing>

=item B<Returns>

=item String: All Ticket/Queue Watchers.

=cut

sub WatchersAsString {
    my $self=shift;

    return (0, "Permission Denied")
      unless ($self->CurrentUserHasRight('Explore'));
    
    return _CleanAddressesAsString ($self->Watchers->EmailsAsString() . ", " .
				    $self->QueueObj->Watchers->EmailsAsString());
}

# {{{ sub AdminCcAsString 

=head2 AdminCcAsString

=item B<Takes>

=item I<nothing>

=item B<Returns>

=item String: All Ticket/Queue AdminCcs.

=cut


sub AdminCcAsString {
    my $self=shift;
    
    return (0, "Permission Denied")
      unless ($self->CurrentUserHasRight('Explore'));
        
    return _CleanAddressesAsString ($self->AdminCc->EmailsAsString() . ", " .
		  $self->QueueObj->AdminCc->EmailsAsString());
  }

# }}}

# {{{ sub CcAsString
=head2 CcAsString

=item B<Takes>  I<nothing>

=item B<Returns> String: All Queue Ccs as a comma delimited set of email addresses.

=cut

sub CcAsString {
    my $self=shift;
    
    return (0, "Permission Denied")
      unless ($self->CurrentUserHasRight('Explore'));
        
    return _CleanAddressesAsString ($self->Cc->EmailsAsString() . ", ".
				    $self->QueueObj->Cc->EmailsAsString());
}

# }}}

# {{{ sub _CleanAddressesAsString
=head2 _CleanAddressesAsString

=item B<Takes> String: A comma delineated address list

=item B<Returns> String: A comma delineated address list

=cut

sub _CleanAddressesAsString {
    my $i=shift;
    $i =~ s/^, //;
    $i =~ s/, $//;
    $i =~ s/, ,/,/g;
    return $i;
}

# }}}

# }}}

# {{{ sub Cc

=head2 Cc

Takes nothing.
Returns a watchers object which contains this ticket's Cc watchers

=cut

sub Cc {
  my $self = shift;

  return (0, "Permission Denied")
    unless ($self->CurrentUserHasRight('Explore'));


  if (! defined ($self->{'Cc'})) {
    require RT::Watchers;
    $self->{'Cc'} = new RT::Watchers ($self->CurrentUser);
    $self->{'Cc'}->LimitToQueue($self->id);
    $self->{'Cc'}->LimitToCc();
  }
  return($self->{'Cc'});
  
}

# }}}

# {{{ sub AdminCc

=head2 AdminCc

Takes nothing.
Returns this ticket's administrative Ccs as an RT::Watchers object

=cut

sub AdminCc {
  my $self = shift;
  
  unless ($self->CurrentUserHasRight('Explore')) {
    return (0, "Permission Denied");
  }
  if (! defined ($self->{'AdminCc'})) {
    require RT::Watchers;
    $self->{'AdminCc'} = new RT::Watchers ($self->CurrentUser);
    $self->{'AdminCc'}->LimitToQueue($self->id);
    $self->{'AdminCc'}->LimitToAdminCc();
  }
  return($self->{'AdminCc'});
  
}
# }}}

# {{{ IsWatcher, IsCc, IsAdminCc

# {{{ sub IsWatcher

=head2 IsWatcher

Takes a param hash with the attributes Type and User. User is either a user object or string containing an email address. Returns true if that user or string
is a ticket watcher. Returns undef otherwise

=cut

sub IsWatcher {
    my $self = shift;
    
    my @args = (Type => 'Cc',
		User => undef);
    
    return (0, "Permission Denied")
      unless ($self->CurrentUserHasRight('Explore'));
    
    $RT::Logger->warn( "Queue::IsWatcher unimplemented");
    return (0);
    #TODO Implement. this sub should perform an SQL match along the lines of the ACL check

}
# }}}

# {{{ sub IsCc

=head2 IsCc

Takes a string. Returns true if the string is a Cc watcher of the current ticket.

=item Bugs

Should also be able to handle an RT::User object

=cut


sub IsCc {
  my $self = shift;
  my $cc = shift;
  
  return ($self->IsWatcher( Type => 'Cc', Identifier => $cc ));
  
}

# }}}

# {{{ sub IsAdminCc

=head2 IsAdminCc

Takes a string. Returns true if the string is an AdminCc watcher of the current ticket.

=item Bugs

Should also be able to handle an RT::User object

=cut

sub IsAdminCc {
  my $self = shift;
  my $admincc = shift;
  
  return ($self->IsWatcher( Type => 'AdminCc', Identifier => $admincc ));
  
}

# }}}

# }}}

# {{{ sub AddWatcher

=head2 AddWatcher

Takes a paramhash of Email, Owner and Type. Type is one of 'Cc' or 'AdminCc',
We need either an Email Address in Email or a userid in Owner

=cut

sub AddWatcher {
  my $self = shift;
  my %args = ( Email => undef,
	       Type => undef,
	       Owner => 0,
	       @_ 
	     );

  
  return (0, "Permission Denied")
    unless ($self->CurrentUserHasRight('ModifyQueueWatchers'));
  
  #TODO: Look up the Email that's been passed in to find the watcher's
  # user id. Set Owner to that value.
    
  require RT::Watcher;
  my $Watcher = new RT::Watcher ($self->CurrentUser);
  return ($Watcher->Create(Scope => 'Queue', 
			   Value => $self->Id,
			   Email => $args{'Email'},
			   Type => $args{'Type'},
			   Owner => $args{'Owner'}
			  ));
}

# }}}

# {{{ sub AddCc

=head2 AddCc

Add a Cc to this queue
Takes a paramhash of Email and Owner. 
We need either an Email Address in Email or a userid in Owner

=cut


sub AddCc {
  my $self = shift;
  return ($self->AddWatcher ( Type => 'Cc', @_));
}
# }}}
	
# {{{ sub AddAdminCc

=head2 AddAdminCc

Add an Administrative Cc to this queue
Takes a paramhash of Email and Owner. 
We need either an Email Address in Email or a userid in Owner

=cut

sub AddAdminCc {
  my $self = shift;
  return ($self->AddWatcher ( Type => 'AdminCc', @_));
}
# }}}

# {{{ sub DeleteWatcher

=head2 DeleteWatcher

DeleteWatcher takes a single argument which is either an email address 
or a watcher id.  It removes that watcher
from this Ticket\'s list of watchers.


=cut


sub DeleteWatcher {
    my $self = shift;
    my $id = shift;
    
    my ($Watcher);
   
    #Check ACLs 
    return (0, "Permission Denied")
	  unless ($self->CurrentUserHasRight('ModifyQueueWatchers'));
    
    
    #If it's a numeric watcherid
   if ($id =~ /^(\d*)$/) { 
       $Watcher = new RT::Watcher($self->CurrentUser);
       $Watcher->Load($id);
       if (($Watcher->Scope  ne 'Queue') or
	   ($Watcher->Value != $self->id) ) {
	   return (0, "Not a watcher for this queue");
       }
       #If we've validated that it is a watcher for this ticket 
       else {
	   $Watcher->Delete();
       }
   }
    #Otherwise, we'll assume it's an email address
    else {
	#Iterate through all the watchers looking for this email address
	#TODO we could speed this up
	while ($Watcher = $self->Watchers->Next) {
	    if ($Watcher->Email =~ /^$id$/) {
		$Watcher->Delete();
	    }
	}
    }
}

# }}}


# {{{ sub ACL 

=head2 ACL

#Returns an RT::ACL object of ACEs everyone who has anything to do with this queue.

=cut

sub ACL  {
  my $self = shift;
  if (!$self->{'acl'}) {
    use RT::ACL;
    $self->{'acl'} = new RT::ACL($self->CurrentUser);
    $self->{'acl'}->LimitScopeToQueue($self->Id);
  }
  
 return ($self->{'acl'});
  
}
# }}}

# {{{ ACCESS CONTROL

# {{{ sub CurrentUserHasRight

=head2 CurrentUserHasRight

Takes one argument. A textual string with the name of the right we want to check.
Returns true if the current user has that right for this queue.
Returns undef otherwise.

=cut

sub CurrentUserHasRight {
  my $self = shift;
  my $right = shift;

  return ($self->HasRight( Principal=> $self->CurrentUser,
                            Right => "$right"));

}

# }}}

# {{{ sub HasRight

=head2 CurrentUserHasRight

Takes a param hash with the fields 'Right' and 'Principal'.
Principal defaults to the current user.
Returns true if the principal has that right for this queue.
Returns undef otherwise.

=cut

# TAKES: Right and optional "Principal" which defaults to the current user
sub HasRight {
    my $self = shift;
        my %args = ( Right => undef,
                     Principal => $self->CurrentUser,
                     @_);
        unless(defined $args{'Principal'}) {
                $RT::Logger->debug("Principal attrib undefined for Queue::HasRight");

        }
        return($args{'Principal'}->HasQueueRight(QueueObj => $self,
          Right => $args{'Right'}));

}

=head2 sub Grant

Grant is a convenience method for creating a new ACE  in the ACL.
It passes off its values along with a scope and applies to of 
the current object.
Grant takes a param hash of the following fields PrincipalType, PrincipalId and Right. 

=cut 

sub Grant {
	my $self = shift;
	my %args = ( PrincipalType => 'User',
		     PrincipalId => undef,
		     Right => undef,
		     @_
		    );
	use RT::ACE;
	my $ACE = new RT::ACE($self->CurrentUser);
	return($ACE->Create(PrincipalType => $args{'PrinicpalType'},
			    PrincipalId =>   $args{'PrincipalId'},
			    Right => $args{'Right'},
			    Scope => 'Queue',
			    AppliesTo => $self->Id ));
}
# 

# }}}

# }}}
1;


