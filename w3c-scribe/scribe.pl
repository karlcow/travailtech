#! perl -w

use strict;  	

# $Id: scribe.perl,v 1.136 2011-05-12 12:01:43 swick Exp $
# Generate minutes in HTML from a text IRC/chat Log.   
#
# Author: David Booth <dbooth@w3.org> 
# License: W3C Software License (see PrintSoftwareLicense below)
#
# Take a raw W3C IRC log, clean it up a bit, and put it into HTML
# to create meeting minutes.  Reads stdin, writes stdout.
# Input format and required scribing conventions are in the documentation:
# http://dev.w3.org/cvsweb/%7Echeckout%7E/2002/scribe/scribedoc.htm
# It's a good idea to pipe the output through "tidy -c".
# (See http://www.w3.org/People/Raggett/tidy/ .)
#
# CONTRIBUTIONS
# Please make improvements to this program!  Check them into CVS (or
# email them to me) and notify me by email.  Thanks!  -- DBooth
# P.S. Please try to avoid dependencies on anything that the
# user might not have installed.  I'd like the code to run on
# pretty much any minimal perl installation.  


######################################################################
# FEATURE WISH LIST / BUG LIST:
#
# 00000. Working on pre/postParagraph formatting.  See nesting problem
# in file:///home/dbooth/w3c/DEV/2002/scribe/test-data/minimal-mit.htm
# First step is to convert to using $scribeParagraphHTMLTemplate.
#
# 0000. BUG: MakeLinks does not work correctly on URLs that contain & because
# it is already escaped into &amp;.  Try test-data/22-tag*
#
# 000. Guess template option (such as -mit) from lines like the following.
# Also guess meeting title from channel name or meeting name?
# 19:28:02 <RRSAgent> RRSAgent has joined &mit
# 19:28:05 <Zakim> Zakim has joined &mit
# 19:28:14 <RalphS> Meeting: MIT Site
# 19:29:06 <ted> ted has joined &mit
# 19:29:34 <Zakim> Team_MIT(site)2:30PM has now started
# 19:29:36 <Zakim> +MIT531
# 19:29:44 <RalphS> zakim, mit531 has Alan, Simon, Ralph
# 19:29:44 <Zakim> +Alan, Simon, Ralph; got it
# 19:30:23 <Alan> Alan has joined &mit
# 19:31:10 <Liam> Liam has joined &mit
# Also define $defaultMeetingTitle from zakim conference name.
#
# 00. Fix formatting processing to prevent generating invalid HTML.
# This would also be a good step toward processing one line at a time,
# and toward making the formatting be fully template-based.
# test-data/validHTML.txt provides a simple input test case.
#
# 0. Embed the CSS, so that it doesn't take so long to load the page.
#
# 0. BUG: URLs written like <http://...> are formatted as IRC statements.
# See the text pasted inside [[ ... ]] at
# http://www.w3.org/2004/11/04-ws-desc-minutes.htm#item06
# The relevant code below may be around line 3581.
#
# 0. Add warning if "Chair: " appears more than once, because it
# is likely to be a chair statement rather than a command.
#
# 0. Recognize ACTIONS that have a date in front like:
#    20050105 ACTION Steve: Report to w3m 
# See http://www.w3.org/2005/03/23-w3m
#
# 0.1 Summarize RESOLUTIONS at the beginning or end.  (Also move summary
# of action items to the beginning?)
#
# 1.2. Add a "Subtopic: ..." command?
#
# 2. Add a warning if a command word appears at the beginning of a line
# but is not followed by a colon.  Ditto for action status word followed
# by any other words (except an action command) on the same line.
# The easiest way to do this may be to have ParseLine return an extra
# value that is a warning string that the caller can issue.  (ParseLine
# should not issue the warning directly, because it is called multiple
# times on the same input text during lookahead.)
#
# 3. Handle weird chars in nick name: <maxf``>
# See http://cvs.w3.org/Team/~checkout~/WWW/2003/11/21-ia-irc.txt?rev=1.139&content-type=text/plain
#
# 4. Improve the guess of who attended, when zakim did not report
# "attendees were ....".  Pick them up from zakim's lines like:
#	<dbooth> zakim, who is here?
#	<Zakim> On the phone I see Mike_Champion, Hugo, Dbooth, Suresh
#	<Zakim> + +1.978.235.aaaa
#	<hugo> Zakim, aaaa is Yin-Leng
#	<Zakim> +Yin-Leng; got it
#	<Zakim> +??P3
#	<Zakim> +S_Kumar
#	<Zakim> +Katia_Sycara
#	<Zakim> +Abbie
#	<Zakim> +Sinisa
#	<Zakim> +MIT308
#	<Zakim> +Sandro
#	<RalphS> zakim, mit308 has DBooth, Ralph
#	<Zakim> +DBooth, Ralph; got it
#	<RalphS> zakim, Steve just arrived in mit308
#	<Zakim> +Steve; got it
# (Examples are from http://www.w3.org/2003/12/11-ws-arch-irc.txt 
# and http://www.w3.org/2003/12/09-mit-irc.txt )
# (Also remember to watch out for zakim's continuation lines.)
#
# 4.1 Make a default Topic, same as Meeting title, if there aren't any.
# I think the only reason to do this is to prevent invalid HTML, as
# a result of having an empty <ul></ul> list in the table of contents.
#
# 5. Add a -keepUrls option to retain IRC lines that were not written
# by the scribe even when the -scribeOnly option is used.
#
# 6. Recognize [[ ...lines... ]] and treat them as a block by
# allowing them to be continuation lines for the same speaker,
# because they are probably pasted in.
#
# 7. Get $actionTemplate and $preSpeakerHTML, etc. from the HTML template,
# so that all formatting info is in the template.
#
# 8. Restructure the code to go through a big loop, processing one line
# at a time, with look-ahead to join continuation lines.
#
# 9. Delete extra stopList from GetNames.  (There is already a global one.)
#
# 10. Integration between scribe.perl and mit-2 minutes extractor:
# I thought further about this and at present I don't know of an easy 
# enough way to make it worthwhile.  One issue: the 2-minutes extractor
# requires Team-only access, so I don't know how scribe.perl would supply
# the user name and password.
# 

######################################################################
# DESIGN PHILOSOPHY
# 0. Easy to use.  It should usually do the right thing, out of the box, 
# without any instructions.  And it should provide guidance (helpful
# error messages) when it fails.
# 1. No installation required.  Please don't add anything that depends
# on a perl module or other software that the user must have (other
# than a standard perl distribution itself).
# 2. Not limited to W3C use.  The program should be usable even for
# non-W3C meetings, by people who are not using RRSAgent, zakim or even IRC.
# (But it's fine to provide enhanced capability when W3C tools are used.)
#
######################################################################
#
# WARNING: The code is a horrible mess.  (Sorry!)  Please hold your nose if 
# you look at it.  If you have something better, or make improvements
# to this (and please do!), please let me know.  Perhaps it's a good 
# example of Fred Brooke's advice in Mythical Man Month: "Plan to throw 
# one away". 
#
######################################################################

#### $diagnostics MUST be initialized early, before anything might call &Warn().
my $diagnostics = "";		# Accumulated diagnostic output.

my ($CVS_VERSION) = q$Revision: 1.136 $ =~ /(\d+[\d\.]*\.\d+)/;
my $versionMessage = 'This is scribe.perl $Revision: 1.136 $ of $Date: 2011-05-12 12:01:43 $ 
Check for newer version at http://dev.w3.org/cvsweb/~checkout~/2002/scribe/

';
$versionMessage =~ s/\$//g; # Prevent CVS from remunging the version in minutes
&Warn($versionMessage);

##### Formatting:
my $preSpeakerHTML = "<cite>";
my $postSpeakerHTML = "</cite>";
my $preWriterHTML = "<cite>";
my $postWriterHTML = "</cite>";
my $prePhoneParagraphHTML = "<p class='phone'>";
my $postPhoneParagraphHTML = "</p>";
my $preIRCParagraphHTML = "<p class='irc'>";
my $postIRCParagraphHTML = "</p>";
my $preResolutionHTML = "<strong class='resolution'>";
my $postResolutionHTML = "</strong>";

my $preTopicHTML = "<h3";
my $postTopicHTML = "</h3>";

# Other globals
my $debug = 1;
my $debugActions = 0;
# According to http://en.wikibooks.org/wiki/IRC :
#   "Although implementations vary, restrictions on nicknames usually 
#   dictate that they be composed only of characters a-z, A-Z, 0-9, underscore, 
#   and dash."
# I also note that at least some implementations forbid a dash at the 
# beginning.  AFAICT xchat (at least) also seems to require at least a letter.
# I also find http://www.kvirc.de/docu/doc_rfc2812.html saying:
#   nickname   =  ( letter / special ) *8( letter / digit / special / "-" )
#   letter     =  %x41-5A / %x61-7A       ; A-Z / a-z
#   digit      =  %x30-39                 ; 0-9
#   special    =  %x5B-60 / %x7B-7D
#                        ; "[", "]", "\", "`", "_", "^", "{", "|", "}"
# I was able to change my nick to _-_- but not starting with - and not
# starting with a number.
# I also find http://www.irchelp.org/irchelp/rfc/chapter2.html#c2_3_1 saying:
#   <nick> ::= <letter> { <letter> | <number> | <special> }
#   <letter> ::= 'a' ... 'z' | 'A' ... 'Z'
#   <number> ::= '0' ... '9'
#   <special> ::= '-' | '[' | ']' | '\' | '`' | '^' | '{' | '}'
# my $namePattern = '[\\w\\d\\_\\-\\.\\`\\\'\\+]+';
my $namePattern = '[a-zA-Z_][a-zA-Z0-9_\\-]*';
# if ($line =~ s/\A(\s?)\<([\w\_\-\.]+)\>(\s?)//)
# warn "namePattern: $namePattern\n";

# URL pattern from http://www.stylusstudio.com/xmldev/200108/post60960.html 
# my $anyUriPattern = '(([a-zA-Z][0-9a-zA-Z+\\-\\.]*:)?/{0,2}[0-9a-zA-Z;/?:@&=+$\\.\\-_!~*\'()%]+)?(#[0-9a-zA-Z;/?:@&=+$\\.\\-_!~*\'()%]+)?';
# $anyUriPattern is too general for our use.   We want to recognize 
# only http:// or https:// absolute URLs.
# 3 parens:
# my $urlPattern = '(http(s?)://[0-9a-zA-Z;/?:@&=+$\\.\\-_!~*\'\(\)%]+)(#[0-9a-zA-Z;/?:@&=+$\\.\\-_!~*\'\(\)%]+)?';
# The above $urlPattern is not matching correctly in this context, because
# HTML special chars & has already been escaped when MakeLinks is called.
# This is a result of the brain-dead way we are currently converting text
# to HTML.
my $urlPattern = '(http(s?)://([0-9a-zA-Z;/?:@=+$\\.\\-_!~*\'\(\)%]|\&amp\;)+)(#([0-9a-zA-Z;/?:@=+$\\.\\-_!~*\'\(\)%]|\&amp\;)+)?';

# These are the recognized commands.  Each command should be a
# single word, so use underscores if you have a multi-word command.
#### TODO: I don't think we need both "IRC Log" and "IRCLog",
#### because &WordVariations will generate the spelling variations.
#### Ditto for Previous_Meeting and PreviousMeeting.
my @ucCommands = qw(Meeting Scribe ScribeNick Topic Chair 
	Present Regrets Agenda 
	IRC Log IRC_Log IRCLog Previous_Meeting PreviousMeeting ACTION
	NamedAnchorHere
	);
# Make lower case and generate spelling variations
my @commands = &Uniq(&WordVariations(map {&LC($_)} @ucCommands));
# Map to preferred spelling:
my %commands = &WordVariationsMap(@ucCommands);
# A pattern to match any of them.  (Be sure to use case-insensitive matching.)
my $commandsPattern = &MakePattern(keys %commands);
# warn "commandsPattern: $commandsPattern\n";

# These are the recognized action statuses.  Each status should be a
# single word, so use underscores if you have a multi-word status.
# See also http://www.w3.org/2001/sw/Europe/200401/actions/
# Note that these are ordered: The order in which they are listed here
# will be the order in which they are listed in the resulting minutes.
# Status words that are on the same line below are treated as synonyms.
# The first word of each subgroup is treated as the preferred spelling
# for that subgroup.
my @ucActionStatusListReferences = 
	(
        [qw( NEW )],
        [qw( PENDING IN_PROGRESS IN_PROCESS NO_PROGRESS NEEDS_ACTION ONGOING ON_GOING CONTINUED CONTINUES CONT)],
        [qw( POSTPONED )],
        [qw( UNKNOWN )],
        [qw( DONE COMPLETED FINISHED CLOSED )],
        [qw( DROPPED RETIRED CANCELLED CANCELED WITHDRAWN )],
	);
# next line edited by ht@w3.org 2008-11-14 to work with perl 5.10 and 'use strict', I hope correctly
my %actionStatusSynonymRefs =
	map { (@{$_}[0], $_) } @ucActionStatusListReferences;
my %closedActionStatuses = map {($_,$_)} 
	(@{$actionStatusSynonymRefs{"DONE"}}, @{$actionStatusSynonymRefs{"DROPPED"}});
my %lcClosedActionStatuses = map {&LC($_)} %closedActionStatuses;
# warn "lcClosedActionStatuses: " . join("\n", %lcClosedActionStatuses) . "\n";
# Flat list of statuses:
my @ucActionStatuses = map { @{$_} } @ucActionStatusListReferences;

my @actionStatuses = &Uniq(&WordVariations(map {&LC($_)} @ucActionStatuses));
my %actionStatuses = (); # Map to preferred spelling. Keys are lower case.
foreach my $statusRef ( @ucActionStatusListReferences )
	{
	my @statuses = @{$statusRef};
	next if !@statuses;
	# Map other spellings to preferred spelling:
	my $pref = $statuses[0];
	foreach my $other (&Uniq(&WordVariations(map {&LC($_)} @statuses)))
		{
		$actionStatuses{$other} = $pref;
		}
	}

#### This foreach loop does not seem to be executing.  Must be a bug.
#### I don't know why.
foreach my $sk (sort keys %actionStatuses)
	{
	my $v = $actionStatuses{$sk};
	warn "actionStatuses map: $sk --> $v\n" if $debugActions;
	}

# A pattern to match any of them.  (Be sure to use case-insensitive matching.)
my $actionStatusesPattern = &MakePattern(keys %actionStatuses);

my @rooms = qw(MIT308 SophiaSofa DISA Fujitsu);

# stopList are non-people.
my @stopList = qw(a q on Re items Zakim Topic muted and agenda Regrets http
	https the RRSAgent Loggy Zakim2 ACTION Chair Meeting DONE PENDING
	WITHDRAWN Scribe 00AM 00PM P IRC Topics DROPPED ger-logger
	yes no abstain Consensus Participants Question RESOLVED strategy
	AGREED Date queue no one in XachBot got it WARNING upcoming);
# @stopList = (@stopList, @rooms);
@stopList = (@stopList, @commands, @actionStatuses);
@stopList = &Uniq(&WordVariations(map {&LC($_)} @stopList));
# Use a hash to quickly determine whether a word is in the list.
my %stopList = &WordVariationsMap(@stopList);
# A pattern to match any of them.  (Be sure to use case-insensitive matching.)
my $stopListPattern = &MakePattern(keys %stopList);

# Globals
my $all = "";			# Input.  
my $template = &DefaultTemplate();	# Template for minutes
my $bestName = "";  		# Name of input format normalizer guessed

# Get options/args
my $minutesURL = "";		# Future URL of the generated minutes
my $warnIfNoRegrets = 0;	# Warn if no "Regrets:" command found?
my $warnIfNoAgenda = 0;		# Warn if no "Agenda:" command found?
my $ralphLinks = 1;		# Convert: -> http://foo text
				# to: <a href="http://foo">text</a> ?
my $embedDiagnostics = 0;	# Embed diagnostics in the generated minutes?
my $draft = 1;                  # Include "DRAFT" warning in minutes.
my $normalizeOnly = 0;		# Output only the normlized input
my $canonicalizeNames = 0;	# Convert all names to their canonical form?
my $scribeOnly = 0;		# Only select scribe lines
my $trustRRSAgent = 0;		# Trust RRSAgent?
my $breakActions = 0;		# Break long action lines?
my $implicitContinuations = 0;	# Option: -implicitContinuations
my @scribeNames = ();		# Example: -scribe dbooth
				# Or: -scribe "David_Booth"
my @scribeNicks = ();		# Example: -scribeNick dbooth
my $useZakimTopics = 1; 	# Treat zakim agenda take-up as Topic change?
my $inputFormat = "";		# Input format, e.g., Plain_Text_Format
my $minScribeLines = 40;	# Min lines to be guessed as scribe.
my $dashTopics = 0;		# Treat "---" as starting a new topic
my $runTidy = 0;		# Pipe the output through "tidy -c"
my $allowSpaceContinuation = 0;	# Leading space indicates continuation line?
my $preferredContinuation = "... "; # Either "... " or " ".
my $embeddedScribeOptions = "";	# Any "ScribeOptions: ..." from input
die if $preferredContinuation eq " " && !$allowSpaceContinuation;

##### Globals used by specific functions (prefix with function name):
my %globalProcessNamedAnchors_anchorIDs = ();
my @globalProcessTopic_agenda = ();	# Plain text
my @globalProcessTopic_agendaIDs = ();	# Named anchors
# my $globalProcessTopic_agenda = "";	# HTML formatted
my $oldGlobalAgenda = "";

my $globalLTPattern = "&lt;";	# TOTO: Change back to <
my $globalGTPattern = "&gt;";	# TOTO: Change back to >
my $globalAmpPattern = "&amp;";	# TOTO: Change back to &


# Loop to get options and input.  The reason this is a loop is that there
# may be options embedded in the input (using "ScribeOptions: ...").
# In which case, we need to restart using those as default options.
my @SAVE_ARGV = @ARGV;
my $restartForEmbeddedOptions = 1;
while($restartForEmbeddedOptions)
	{
	$restartForEmbeddedOptions = 0;

	@ARGV = @SAVE_ARGV;
	my @args = ();
	$template = &DefaultTemplate();
	my $scribeDefaultOptions = 'SCRIBEOPTIONS';
	if ($embeddedScribeOptions) {
		# Put embedded options at front of list for lower priority
		@ARGV = (split(/\s+/, $embeddedScribeOptions), @ARGV);
	}
	if ($ENV{$scribeDefaultOptions}) {
		# Put env options at front of list for lowest priority
		@ARGV = (split(/\s+/, $ENV{$scribeDefaultOptions}), @ARGV);
	}
	while (@ARGV)
		{
		my $a = shift @ARGV;
		if (0) {}
		elsif ($a eq "") 
			{ }
                elsif ($a eq "-minutes")
                        {
			$minutesURL = shift @ARGV; 
			&Die("ERROR: -minutes option requires an argument\n")
				if !defined($minutesURL);
			&Die("ERROR: -minutes option requires an absolute http: URL\n")
				if $minutesURL !~ m/\A(http|https)\:/;
			$minutesURL =~ s/\#.*\Z//; 	# Strip off frag id
			}
                elsif ($a eq "-embedDiagnostics")
                        { $embedDiagnostics = 1; }
                elsif ($a eq "-noEmbedDiagnostics")
                        { $embedDiagnostics = 0; }
                elsif ($a eq "-draft")
                        { $draft = 1; }
                elsif ($a eq "-final")
                        { $draft = 0; }
		elsif ($a eq "-normalize") 
			{ $normalizeOnly = 1; }
		elsif ($a eq "-sampleInput") 
			{ print STDOUT &SampleInput(); exit 0; }
		elsif ($a eq "-sampleOutput") 
			{ 
			&Warn("\nWARNING: Replacing input because of -sampleOutput option\n\n") if $all;
			$all = &SampleInput(); 
			}
		elsif ($a eq "-sampleTemplate") 
			{ print STDOUT &DefaultTemplate(); exit 0; }
		elsif ($a eq "-scribeOnly") 
			{ $scribeOnly = 1; }
		elsif ($a eq "-canon") 
			{ $canonicalizeNames = 1; }
		elsif ($a eq "-noBreakActions") 
			{ $breakActions = 0; }
		elsif ($a eq "-breakActions") 
			{ $breakActions = 1; }
		elsif ($a eq "-noTrustRRSAgent") 
			{ $trustRRSAgent = 0; }
		elsif ($a eq "-trustRRSAgent") 
			{ $trustRRSAgent = 1; }
		elsif ($a eq "-teamSynonyms") 
			{ &Warn("\nWARNING: -teamSynonyms option no longer implemented\n\n"); }
		elsif ($a eq "-plain") 
			{ $template = &PlainTemplate(); }
		elsif ($a eq "-mit") 
			{ $template = &MITTemplate(); }
		elsif ($a eq "-team") 
			{ $template = &TeamTemplate(); }
		elsif ($a eq "-member") 
			{ $template = &MemberTemplate(); }
		elsif ($a eq "-world") 
			{ $template = &PublicTemplate(); }
		elsif ($a eq "-public") 
			{ $template = &PublicTemplate(); }
		elsif ($a eq "-template") 
			{ 
			my $templateFile = shift @ARGV; 
			if (-e $templateFile)
			    {
			    if (my $t = &GetTemplate($templateFile)) {
				$template = $t; }
			    else {
				&Warn("ERROR: Empty template: $templateFile\n"); }
			    }
			else {
			    &Warn("ERROR: Template file not found: $templateFile\n") }
			}
		elsif ($a eq "-debug") 
			{ $debug = 1; }
		elsif ($a eq "-noUseZakimTopics" || $a eq "-noZakimTopics") 
			{ $useZakimTopics = 0; }
		elsif ($a eq "-useZakimTopics" || $a eq "-zakimTopics") 
			{ $useZakimTopics = 1; }
		elsif ($a eq "-implicitContinuations"
			|| $a eq "implicitContinuation") 
			{ $implicitContinuations = 1; }
		elsif ($a eq "-allowSpaceContinuation") 
			{ $allowSpaceContinuation = 1; }
		elsif ($a eq "-disallowSpaceContinuation") 
			{ $allowSpaceContinuation = 0; }
		elsif ($a eq "-minScribeLines") 
			{ $minScribeLines = shift @ARGV; }
		elsif ($a eq "-inputFormat") 
			{ $inputFormat = shift @ARGV; }
		elsif ($a eq "-dashTopics" || $a eq "-philippe" || $a eq "-plh") 
			{ $dashTopics = 1; }
		elsif ($a eq "-noDashTopics" || $a eq "-noPhilippe" || $a eq "-noPlh") 
			{ $dashTopics = 0; }
		elsif ($a eq "-scribe" || $a eq "-scribeName") 
			{ push(@scribeNames, shift @ARGV); }
		elsif ($a eq "-scribeNick" || $a eq "-scribeNickname") 
			{ push(@scribeNicks, shift @ARGV); }
		elsif ($a eq "-tidy") 
			{ 
			my $tidyCommand = "tidy -c -asxhtml";
			open(STDOUT, "| $tidyCommand") || &Die("ERROR: Could not run \"$tidyCommand\"\nYou need to have tidy installed on your system to use\nthe -tidy option.\n");
			}
		elsif ($a eq "-help" || $a eq "-h") 
			{ &Die("For help, see http://dev.w3.org/cvsweb/%7Echeckout%7E/2002/scribe/scribedoc.htm\n"); }
		elsif ($a =~ m/\A\-/)
			{ 
			&Warn("ERROR: Unknown option: $a\n"); 
			&Die("For help, see http://dev.w3.org/cvsweb/%7Echeckout%7E/2002/scribe/scribedoc.htm\n"); 
			}
		else	
			{ push(@args, $a); }
		}
	@ARGV = @args;
	@ARGV = map {glob} @ARGV;	# Expand wildcards in arguments

	# Get input:
	$all =  join("",<>) if !$all;
	&Die("\nERROR: Empty input.\n\n") if !$all;

	# Delete control-M's if any.  Cygwin seems to add them. :(
	$all =~ s/\r//g;

	# Normalize input format.  This accepts several formats of input
	# and puts it into a common format.
	# The %inputFormats is the list of known normalizer functions.
	# Each one is defined below.
	# Just add another to the list if you want to recognize another format.
	# Each function takes $all (the input text) as input and returns
	# a pair: ($score, $newAll). 
	#	$score is a value [0,1] indicating how well it matched (fraction
	#		of lines conforming to this format).
	#	$newAll is the normalized input.
	# Each key, value pair in the %inputFormats map is the name of the
	# function and the function address.
	my %inputFormats = (
		# functionName, functionAddress,
		"XChat_Timestamped_Log_Format", \&XChat_Timestamped_Log_Format,
		"RRSAgent_Text_Format", \&RRSAgent_Text_Format, 
		"RRSAgent_HTML_Format", \&RRSAgent_HTML_Format, 
		"RRSAgent_Visible_HTML_Text_Paste_Format", \&RRSAgent_Visible_HTML_Text_Paste_Format,
		"Mirc_Text_Format", \&Mirc_Text_Format,
		"Mirc_Timestamped_Log_Format", \&Mirc_Timestamped_Log_Format,
 		"Irssi_ISO8601_Log_Text_Format", \&Irssi_ISO8601_Log_Text_Format,
		"Yahoo_IM_Format", \&Yahoo_IM_Format,
		"Plain_Text_Format", \&Plain_Text_Format,
		"Normalized_Format", \&Normalized_Format,
		);
	my @inputFormats = keys %inputFormats;

	if ($inputFormat && !exists($inputFormats{$inputFormat}))
		{
		&Warn("\nWARNING: Unknown input format specified: $inputFormat\n");
		&Warn("Reverting to guessing the format.\n\n");
		$inputFormat = "";
		}
	# Try each known format, and see which one matches best.
	my $bestScore = 0;
	my $bestAll = "";
	$bestName = "";  	# Global var because we access it later
	foreach my $f (@inputFormats)
		{
		my $fAddress = $inputFormats{$f};
		my ($score, $newAll) = &$fAddress($all);
		# warn "$f: $score\n";
		if ($score > $bestScore)
			{
			$bestScore = $score;
			$bestAll = $newAll;
			$bestName = $f;
			}
		}
	my $bestScoreString = sprintf("%4.2f", $bestScore);
	if ($inputFormat)
		{
		# warn "INPUT FORMAT: $inputFormat\n";
		# Format was specified using -inputFormat option
		my $fAddress = $inputFormats{$inputFormat};
		my ($score, $newAll) = &$fAddress($all);
		my $scoreString = sprintf("%4.2f", $score);
		$all = $newAll;
		&Warn("\nWARNING: Input looks more like $bestName format (score $bestScoreString),
	but \"-inputFormat $inputFormat\" (score $scoreString) was specified.\n\n")
			if $score < $bestScore;
		}
	else	{
		&Warn("Guessing input format: $bestName (score $bestScoreString)\n\n");
		&Die("ERROR: Could not guess input format.\n") if $bestScore == 0;
		&Warn("\nWARNING: Low confidence ($bestScoreString) on guessing input format: $bestName\nPlease email an example of your input log format to dbooth\@w3.org\nso that I can consider adding support for your log format.\n\n")
			if $bestScore < 0.7;
		$all = $bestAll;
		}

	# Preprocess to perform s/old/new/ substitutions
	# and i/where/line/ insertions.
	$all = &ProcessEdits($all);

	# Look for embedded options, and restart if we find some.
	# (Except we do NOT re-read the input.  We keep $all as is.)
	while ($all =~ s/\n\<[^\<\>]+\>\s*ScribeOption(s?)\s*\:(.*)\n/\n/i)
		{
		my $newOptions = &Trim($2);
		$embeddedScribeOptions .= " $newOptions";
		# &Warn("FOUND new ScribeOptions: $newOptions\n");
		$restartForEmbeddedOptions = 1;
		}
	if ($restartForEmbeddedOptions)
		{
		&Warn("Found embedded ScribeOptions: $embeddedScribeOptions\n\n*** RESTARTING DUE TO EMBEDDED OPTIONS ***\n\n");
		# Prevent input from being re-normalized:
		push(@SAVE_ARGV, ("-inputFormat", "Normalized_Format"));
		}
	}

if ($canonicalizeNames) 
	{
	# Strip -home from names.  (Convert alan-home to alan, for example.)
	$all =~ s/(\w+)\-home\b/$1/ig;
	# Strip -lap from names.  (Convert alan-lap to alan, for example.)
	$all =~ s/(\w+)\-lap\b/$1/ig;
	# Strip -iMac from names.  (Convert alan-iMac to alan, for example.)
	$all =~ s/(\w+)\-iMac\b/$1/ig;
	}

# Determine scribe name and scribeNick.
# This needs to be done BEFORE handling $dashTopics and $useZakimTopics
# because they insert <scribe> lines, which would otherwise mess up
# the lookahead processing in GetScribeNamesAndNicks.
if (1)
	{
	my ($newAll, $scribeNamesRef, $scribeNicksRef) = 
		&GetScribeNamesAndNicks($all, \@scribeNames, \@scribeNicks);
	$all = $newAll;
	@scribeNames = @$scribeNamesRef;
	@scribeNicks = @$scribeNicksRef;
	&Warn("Scribes: ", join(", ", @scribeNames), "\n") 
		if scalar(@scribeNames) > 1;
	&Warn("ScribeNicks: ", join(", ", @scribeNicks), "\n")
		if scalar(@scribeNicks) > 1;
	}

if ($useZakimTopics)
	{
	# Treat zakim statements like:
	#	<Zakim> agendum 2. "UTF16 PR issue" taken up [from MSMscribe]
	# as equivalent to:
	#	<inserted> Topic: UTF16 PR issue
	$all = "\n$all\n";
	while ($all =~ s/\n\<Zakim\>\s*agendum\s*\d+\.\s*\"(.+)\"\s*taken up\s*((\[from (.*?)\])?)\s*\n/\n\<inserted\> Topic\: $1\n/i)
		{
		# warn "Zakim Topic: $1\n";
		}
	}

# See if the $dashTopics option should be used.  That option causes
# dash lines to indicate the start of a new topic, such as:
#	<plh> ---
#	<plh> Move to Stata Center
#	<plh> Alan: What is the status of the Stata move?
# which will be converted to the following if $dashTopics is used: 
#	<plh> Topic: Move to Stata Center
#	<plh> Alan: What is the status of the Stata move?
# First see how many "Topic:" lines we have:
my @topicLines = grep 
	{
	die if !defined($_);
	my ($writer, $type, $value, $rest, undef) = &ParseLine($_);
	$type eq "COMMAND" && $value eq "topic" && $rest ne "";
	} split(/\n/, $all);
# Now see how many we'd get if we used the $dashTopics option:
my ($allDashTopics, $nDashTopics) = &ConvertDashTopics($all);
# Now decide what to do.  There are three variables, which we can treat
# as booleans (0 or non-0) for the purpose of covering all cases:
#	$dashTopics
#	$nDashTopics
#	@topicLines
# For completeness, we'll just enumerate the 8 cases:
if (0) {}
elsif ((!$dashTopics) && (!$nDashTopics) && (!@topicLines))
	{ &Warn("\nWARNING: No \"Topic:\" lines found.\n\n"); }
elsif ((!$dashTopics) && (!$nDashTopics) && ( @topicLines))
	{ }
elsif ((!$dashTopics) && ( $nDashTopics) && (!@topicLines))
	{ 
	&Warn("\nWARNING: No \"Topic:\" lines found, but dash separators were found.  \nDefaulting to -dashTopics option.\n\n"); 
	$dashTopics = 1;
	}
elsif ((!$dashTopics) && ( $nDashTopics) && ( @topicLines))
	{ 
	&Warn("\nWARNING: Dash separator lines found.  If you intended them to mark\nthe start of a new topic, you need the -dashTopics option.\nFor example:\n        <Philippe> ---\n        <Philippe> Review of Action Items\n\n");
	}
elsif (( $dashTopics) && (!$nDashTopics) && (!@topicLines))
	{ &Warn("\nWARNING: No \"Topic:\" lines found.\n\n"); }
elsif (( $dashTopics) && (!$nDashTopics) && ( @topicLines))
	{ 
	&Warn("\nWARNING: -dashTopics option used, but no separator lines found.\nFor example:\n        <Philippe> ---\n        <Philippe> Review of Action Items\n\n");
	}
elsif (( $dashTopics) && ( $nDashTopics) && (!@topicLines))
	{ }
elsif (( $dashTopics) && ( $nDashTopics) && ( @topicLines))
	{ }
else { die "INTERNAL ERROR: Internal logic error "; }
# Finally, apply the $dashTopics option if enabled.
if ($dashTopics)
	{
	$all = $allDashTopics;
	}

# Remove duplicate Topic lines
if (1)
	{
	my @lines = split(/\n/, $all);
	my @nonredundantLines = ();
	my $previousTopic = "";
	foreach my $line (@lines)
		{
		my $ignore = 0;
		die if !defined($line);
		my ($writer, $type, $value, $rest, undef) = &ParseLine($line);
		if ($type eq "COMMAND" && $value eq "topic")
			{
			$ignore = 1 if (&LC($rest) eq &LC($previousTopic));
			$previousTopic = $rest;
			}
		push(@nonredundantLines, $line) if !$ignore;
		}
	$all = "\n" . join("\n", @nonredundantLines) . "\n";
	}

if ($normalizeOnly)
	{
	# This isn't really very good.  I thought this would be a
	# useful option, but now I'm not so sure, because several
	# of the scribe.perl commands (such as "Scribe: ...") are
	# removed when they're processed.
	my $t = join("\n", grep {m/\A\</;} split(/\n/, $all)) . "\n";
	print "$t\n";
	exit 0;
	}

# Get attendee list, and canonicalize names within the document:
my @uniqNames = ();
my $allNameRefsRef;
($all, $allNameRefsRef, @uniqNames) = &GetNames($all);
my @allNames = map { ${$_} } @{$allNameRefsRef};

push(@allNames,"scribe");
my @allSpeakerPatterns = map {quotemeta($_)} @allNames;
# my $speakerPattern = "((" . join(")|(", @allSpeakerPatterns) . "))";
# my $speakerPattern = join("|", @allSpeakerPatterns);
my $speakerPattern = $namePattern; # Not sure what else to use here
# warn "speakerPattern: $speakerPattern\n";

# Get the list of people present.
# First look for zakim output, as the default:
my @present = &GetPresentFromZakim($all); 
&Warn("Default Present: " . join(", ", @present) . "\n") if @present;
# Now look for explicit "Present: ... " commands:
die if !defined($all);
($all, @present) = &GetPresentOrRegrets("Present", 3, $all, @present); 
die if !defined($all);

# Get the list of regrets:
my @regrets = ();	# People who sent regrets
($all, @regrets) = &GetPresentOrRegrets("Regrets", 0, $all, ()); 

# Grab meeting name:
my $title = "";
if ($all =~ s/\n\<$namePattern\>\s*(Meeting)\s*\:\s*(.*)\n/\n/i)
	{ $title = &EscapeHTML($2); }
else 	{ 
	&Warn("\nWARNING: No meeting title found!
You should specify the meeting title like this:
<dbooth> Meeting: Weekly Baking Club Meeting\n\n");
	}

# Grab agenda URL:
my $agendaLocation;
if ($all =~ s/\n\<$namePattern\>\s*(Agenda)\s*\:\s*(http(s)?:\/\/\S+)\n/\n/i)
	{ $agendaLocation = &EscapeHTML($2);
	  &Warn("Agenda: $agendaLocation\n");
      }
else 	{ 
	if ($warnIfNoAgenda)
		{
		&Warn("\nWARNING: No agenda location found (optional).
If you wish, you may specify the agenda like this:
<dbooth> Agenda: http://www.example.com/agenda.html\n\n");
		}
	}

# Grab Previous meeting URL:
my $previousURL = "SV_PREVIOUS_MEETING_URL";
if ($all =~ s/\n\<$namePattern\>\s*(Previous[ _\-]*Meeting)\s*\:\s*(.*)\n/\n/i)
	{ $previousURL = &EscapeHTML($2); }

# Grab Chair:
my $chair = "SV_MEETING_CHAIR";
if ($all =~ s/\n\<$namePattern\>\s*(Chair(s?))\s*\:\s*(.*)\n/\n/i)
	{ $chair = &EscapeHTML($3); }
else 	{ 
	&Warn("\nWARNING: No meeting chair found!
You should specify the meeting chair like this:
<dbooth> Chair: dbooth\n\n");
	}

# Grab IRC LOG URL.  Do this before looking for the date, because
# we can figure out the date from the IRC log name.
my $logURL = "";
# <scribe> IRC: http://www.w3.org/2005/01/05-arch-irc
$logURL = $4 if $all =~ s/\n\<$namePattern\>\s*(IRC|Log|(IRC([\s_]*)Log))\s*\:\s*(.*)\n/\n/i;
# <RRSAgent>   recorded in http://www.w3.org/2002/04/05-arch-irc#T15-46-50
$logURL = $3 if $all =~ m/\n\<(RRSAgent|Zakim)\>\s*(recorded|logged)\s+in\s+(http\:([^\s\#]+))/i;
$logURL = $3 if $all =~ m/\n\<(RRSAgent|Zakim)\>\s*(see|recorded\s+in)\s+(http\:([^\s\#]+))/i;
# <RRSAgent> RRSAgent is logging to http://www.w3.org/2005/01/05-arch-irc
$logURL = $4 if $all =~ m/\n\<(RRSAgent|Zakim)\>.*((\s+is)?\s+logging\s+to)\s+(http\:([^\s\#]+))/i;
$logURL = &EscapeHTML($logURL) if $logURL;

# Grab and remove date from $all
my ($day0, $mon0, $year, $monthAlpha) = &GetDate($all, $logURL);

# Guess the $minutesURL?
if (!$minutesURL)
	{
	$minutesURL = &GuessMinutesURL($all);
	&Warn("Guessing minutes URL: $minutesURL\n") if $minutesURL;
	}

# Find and format action items
my $formattedActions;
($all, $formattedActions) = &GetActions($all);
# die "Returned from GetActions\n";

# Highlight ACTION items:
warn "Highlighting actions....\n" if $debugActions;
$formattedActions =~ s/\bACTION\s*\:(.*)/\<strong\>ACTION\:\<\/strong\>$1/ig;
# Highlight in-line ACTION status:
foreach my $status (@actionStatuses)
	{
	my $ucStatus = $actionStatuses{$status}; # Map to preferred spelling
	$formattedActions =~ s/\[$status\]/<strong>[$ucStatus]<\/strong>/ig;
	}
warn "Done formatting actions!\n" if $debugActions;

$all = &IgnoreGarbage($all);

if ($implicitContinuations)
	{
	# warn "Scribing style: -implicitContinuations\n";
	$all = &ExpandImplicitContinuations($all);
	}
else	{
	# warn "Scribing style: -explicitContinuations\n";
	if (&ProbablyUsesImplicitContinuations($all))
		{
		&Warn("\nWARNING: Input appears to use implicit continuation lines.\n");
		&Warn("You may need the \"-implicitContinuations\" option.\n\n");
		}
	}

if (0)
{
warn "############# TEST DATA ONLY #############\n";
$all = '<scribe> dbooth: dbooth said 1
<scribe>  dbooth said 2 # This should be continuation
<hugo> Topic: New topic A
<scribe> ... dbooth said 3 # This should be speaker david
<scribe> dbooth: dbooth said 4 # This should be continuation
<scribe> Topic: New topic B
<scribe> ... dbooth said 5 # This should be UNKNOWN_SPEAKER
';
}
# Remove <scribe> from scribe lines, and make lines with the same
# use continuation lines.
my $debugCurrentSpeaker = 0;
my @lines = split(/\n/, $all);
my $prevSpeaker = "UNKNOWN_SPEAKER"; # Most recent speaker minuted by scribe
my $pleaseContinue = 0;
for (my $i=0; $i<@lines; $i++)
	{
	die if !defined($lines[$i]);
	my ($writer, $type, $value, $rest, $allButWriter) = &ParseLine($lines[$i]);
	warn "\nprevSpeaker: $prevSpeaker pleaseContinue: $pleaseContinue line: $lines[$i]\n" if $debugCurrentSpeaker;
	warn "writer: $writer, type: $type, value: $value, rest: $rest, allBut: $allButWriter\n" if $debugCurrentSpeaker;
	# $type	is one of: COMMAND STATUS SPEAKER CONTINUATION PLAIN
	if (&LC($writer) ne "scribe")
		{
		warn "writer NOT scribe\n" if $debugCurrentSpeaker;
		$pleaseContinue = 0;
		next;
		}
	# $writer is scribe
	if ($type eq "COMMAND") 
		{ 
		warn "type is COMMAND\n" if $debugCurrentSpeaker;
		$pleaseContinue = 0; 
		$prevSpeaker = "UNKNOWN_SPEAKER";
		}
	elsif ($type eq "STATUS") 
		{ 
		warn "type is STATUS\n" if $debugCurrentSpeaker;
		$pleaseContinue = 0; 
		$prevSpeaker = "UNKNOWN_SPEAKER";
		}
	elsif ($type eq "PLAIN") 
		{ 
		warn "type is PLAIN\n" if $debugCurrentSpeaker;
		$lines[$i] = "$rest"; # Eliminate <scribe>
		$pleaseContinue = 0; 
		$prevSpeaker = "scribe";
		}
	elsif ($type eq "SPEAKER")
		{
		warn "type is SPEAKER\n" if $debugCurrentSpeaker;
		if ($pleaseContinue && &LC($value) eq &LC($prevSpeaker))
			{
			warn "  ... continuing\n" if $debugCurrentSpeaker;
			# "... rest" or
			# " rest"
			$lines[$i] = $preferredContinuation . $rest;
			}
		else	{
			warn "  Restating speaker\n" if $debugCurrentSpeaker;
			# speaker: rest
			$lines[$i] = "$value\: $rest";
			}
		$prevSpeaker = $value;
		$pleaseContinue = 1;
		}
	elsif ($type eq "CONTINUATION")
		{
		warn "type is CONTINUATION\n" if $debugCurrentSpeaker;
		if ($pleaseContinue)
			{
			warn "  ... continuing\n" if $debugCurrentSpeaker;
			# "... rest" or
			# " rest"
			$lines[$i] = $preferredContinuation . $rest;
			}
		else	{
			warn "  Restating speaker\n" if $debugCurrentSpeaker;
			# speaker: rest
			$lines[$i] = "$prevSpeaker\: $rest";
			}
		$pleaseContinue = 1;
		}
	else	{
		&Warn("\nINTERNAL ERROR: Unknown line type: ($type) returned by ParseLine(...)\n\n");
		}
	}
$all = "\n" . join("\n", @lines) . "\n";


#### Experimental code (untested) commented out:
if (0) 
{
# warn "all: $all\n";
my ($newTemplate, %embeddedTemplates) = &GetEmbeddedTemplates($template);
foreach my $n (keys %embeddedTemplates)
	{
	warn "=============== template $n =================\n";
	warn $embeddedTemplates{$n} . "\n";
	warn "==============================================\n";
	}
}


######################### HTML ##########################
# From now on, $all is HTML!!!!!


##############  Escape < > as &lt; &gt; ################
my $oldProcessingModel = 1;
if ($oldProcessingModel)	{ 
	# Escape < and >:
	$all = &EscapeHTML($all);
	}
else	{ # This works (tested 3/24/05):
	# $all = &MapProcessLines($all, \&TempProcessEscapeHTML);
	}
# print $all; exit 0;

# Insert named anchors for ACTION item locations:
my @allLines;
if ($oldProcessingModel) # 
	{ # old processing model
	@allLines = split(/\n/, $all);
	my %actionIDs = ();
	for (my $i=0; $i<@allLines; $i++)
		{
		# Looking for:
		# 	<inserted> NamedAnchorHere: action01
		# die if !defined($i);
		# die if !defined(@allLines);
		# die if !defined($allLines[$i]);
		# warn "SEEN: $allLines[$i]\n" if $allLines[$i] =~ m/NamedAnchorHere/;
		next if $allLines[$i] !~ m/\A\&lt\;[^ \t\<\>\&]+\&gt\;\s*NamedAnchorHere\:\s*(\S+)\s*\Z/i;
		# warn "FOUND: $allLines[$i]\n";
		# Found one.  Convert it to a real named anchor.
		my $actionID = $1;
		# die if !defined($actionID);
		&Warn("WARNING: Duplicate named anchor: $actionID\n") if (exists($actionIDs{$actionID}));
		$actionIDs{$actionID} = $actionID;
		$allLines[$i] = '<a name="' . $actionID . '"></a>';
		}
	$all = "\n" . join("\n", @allLines) . "\n";
	}
else	{ # new processing model
	# Working:
	# 	&ProcessNamedAnchors
	#	&ProcessActions (maybe)
	#
	##### Otherwise:
	$all = &MapProcessLines($all, 
		\&ProcessNamedAnchors, 
		\&ProcessActions,
		\&ProcessTopic,
		\&ProcessScribeStatement,
		\&ProcessIRCStatement,
		\&TempProcessEscapeHTML);
	}

# die "AGENDA: $oldGlobalAgenda\n";

### *** stopped here ***.  Incrementally converting these sections
### to new processing model.

if ($oldProcessingModel)
	{ # Old processing model
	# Highlight in-line ACTION items:
	@allLines = split(/\n/, $all);
	for (my $i=0; $i<@allLines; $i++)
		{
		next if $allLines[$i] =~ m/\&gt\;\s*Topic\s*\:/i;
		$allLines[$i] =~ s/\bACTION\s*\:(.*)/\<strong\>ACTION\:\<\/strong\>$1/i;
		}
	$all = "\n" . join("\n", @allLines) . "\n";
	# Highlight in-line ACTION status:
	foreach my $status (@actionStatuses)
		{
		my $ucStatus = $status;
		$ucStatus =~ tr/a-z/A-Z/; # Make upper case but not preferred spelling
		$all =~ s/\[\s*$status\s*\]/<strong>[$ucStatus]<\/strong>/ig;
		}
	}
else	{ # new processing model
	##### Otherwise:
	# $all = &MapProcessLines($all, \&ProcessActions);
	}

# Format topic titles (i.e., collect agenda):
if (1)
	{ # Old processing model
	my %agenda = ();
	my $itemNum = "item01";
	while ($all =~ s/\n(\&lt\;$namePattern\&gt\;\s+)?Topic\:\s*(.*)\n/\n$preTopicHTML id\=\"$itemNum\"\>$2$postTopicHTML\n/i)
		{
		$agenda{$itemNum} = $2;
		$itemNum++;
		}
	if (!scalar(keys %agenda)) 	# No "Topic:"s found?
		{
		&Warn("\nWARNING: No \"Topic: ...\" lines found!  \nResulting HTML may have an empty (invalid) <ol>...</ol>.\n\nExplanation: \"Topic: ...\" lines are used to indicate the start of \nnew discussion topics or agenda items, such as:\n<dbooth> Topic: Review of Amy's report\n\n");
		}
	foreach my $item (sort keys %agenda)
		{
		$oldGlobalAgenda .= '<li><a href="#' . $item . '">' . $agenda{$item} . "</a></li>\n";
		}
	}
else
	{ # new processing model
	##### Otherwise:
	$all = &MapProcessLines($all, \&ProcessTopic);
	if (!@globalProcessTopic_agenda) 	# No "Topic:"s found?
		{
		&Warn("\nWARNING: No \"Topic: ...\" lines found!  \nResulting HTML may have an empty (invalid) <ol>...</ol>.\n\nExplanation: \"Topic: ...\" lines are used to indicate the start of \nnew discussion topics or agenda items, such as:\n<dbooth> Topic: Review of Amy's report\n\n");
		}
	}

#### Another experiment
if (0)
	{
	my $writer;
	for (my $i=0; $i<@lines; $i++)
		{
		my ($nextWriter, $nextRest) = &WriterRest($lines[$i]);
		next if $nextWriter ne $writer;
		}
	}

### @@@ Fix IRC/Phone distinctionxc
# Break into paragraphs:
# my $scribeParagraphHTMLTemplate = "$prePhoneParagraphHTML\n\$speakerHTML\$statementHTML\n$postPhoneParagraphHTML\n\n";
if ($oldProcessingModel)
	{
	$all =~ s/\n(([^\ \.\<\&].*)(\n\ *\.\.+.*)*)/\n$prePhoneParagraphHTML\n$1\n$postPhoneParagraphHTML\n/g;
	}
if (0)
	{
	my $body = "";
	my @lines = grep {m/\A(\<$namePattern\>)?\s*\S/} split(/\n/, $all);
	for (my $i=0; $i<@lines; $i++)
		{
		my @parsedLine = &ParseLine($lines[$i]);
		my ($writer, $type, $value, $rest, $allButWriter) = @parsedLine;
		next if ($allButWriter eq ""); 	# Ignore empty lines
		if ($type eq "COMMAND")
			{
			}
		elsif ($type eq "STATUS")
			{
			}
		elsif ($type eq "SPEAKER")
			{
			}
		elsif ($type eq "CONTINUATION")
			{
			}
		elsif ($type eq "PLAIN")
			{
			}
		}
	}

if ($oldProcessingModel)
	{
	# $all =~ s/\n(([^\ \.\<\&].*)(\n\ *\.\.+.*)*)/\n$prePhoneParagraphHTML\nFOO $1 FUM\n$postPhoneParagraphHTML\n/g;
	$all =~ s/\n((&.*)(\n\ *\.\.+.*)*)/\n$preIRCParagraphHTML\n$1\n$postIRCParagraphHTML\n/g;
	# $all =~ s/\n((&.*)(\n\ *\.\.+.*)*)/\n$preIRCParagraphHTML\nBAR $1 BAH\n$postIRCParagraphHTML\n/g;
	}

# Highlight resolutions
$all =~ s/\n\s*(RESOLUTION|RESOLVED): (.*)/\n${preResolutionHTML}RESOLUTION: $2$postResolutionHTML/g;

# Bold or <strong> speaker name:
# Change "<speaker> ..." to "<b><speaker><b> ..."
my $preUniq = "PreSpEaKerHTmL";
my $postUniq = "PostSpEaKerHTmL";
my $preIRCUniq = "PreIrCSpEaKerHTmL";
my $postIRCUniq = "PostIrCSpEaKerHTmL";
$all =~ s/\n(\&lt\;($namePattern)\&gt\;)\s*/\n\&lt\;$preIRCUniq$2$postIRCUniq\&gt\; /ig;
# Change "speaker: ..." to "<b>speaker:<b> ..."
# $all =~ s/\n($speakerPattern)\:\s*/\n$preUniq$1\:$postUniq /ig;
if (1)
	{
	my $done = "";
	while ($all =~ m/\A((.|\n)*?)\n($speakerPattern)\:\s*/i)
		{
		my $pre = $1;
		my $post = $';
		my $speaker = $3;
		my $match = $&;
		my $new = "\n$preUniq$speaker\:$postUniq ";
		if (exists($stopList{&LC($speaker)}) 
		  && &LC($speaker) ne "scribe")
			{ $done .= $match; } # No change
		else	{ $done .= $pre . $new; }
		$all = $post;
		}
	$done .= $all;
	$all = $done;
	}
$all =~ s/$preUniq/$preSpeakerHTML/g;
$all =~ s/$postUniq/$postSpeakerHTML/g;
$all =~ s/$preIRCUniq/$preWriterHTML/g;
$all =~ s/$postIRCUniq/$postWriterHTML/g;

if ($oldProcessingModel)
	{
	# Add <br /> before continuation lines:
	$all =~ s/\n(\ *\.)/ <br>\n$1/g;
	# Collapse multiple <br />s:
	$all =~ s/<br>((\s*<br>)+)/<br \/>/ig;
	# Standardize continuation lines:
	# $all =~ s/\n\s*\.+/\n\.\.\./g;
	# Make links:
	$all = &MakeLinks($all);
	}

# Put into template:
# $all =~ s/\A\s*<\/p>//;
# $all .= "\n<\/p>\n";
my $presentAttendees = join(", ", @present);
my $regrets = join(", ", @regrets);

&Die("\nERROR: Empty minutes template\n\n") if !$template;
my $result = $template;
$result =~ s/SV_MEETING_DAY/$day0/g;
$result =~ s/SV_MEETING_MONTH_ALPHA/$monthAlpha/g;
$result =~ s/SV_MEETING_YEAR/$year/g;
$result =~ s/SV_MEETING_MONTH_NUMERIC/$mon0/g;
$result =~ s/SV_PREVIOUS_MEETING_URL/$previousURL/g;
$result =~ s/SV_MEETING_CHAIR/$chair/g;
my $scribeNames = join(", ", @scribeNames);
$result =~ s/SV_MEETING_SCRIBE/$scribeNames/g;
$result =~ s/SV_MEETING_AGENDA/$oldGlobalAgenda/g;
$result =~ s/SV_TEAM_PAGE_LOCATION/SV_TEAM_PAGE_LOCATION/g;

$result =~ s/SV_REGRETS/$regrets/g;
$result =~ s/SV_PRESENT_ATTENDEES/$presentAttendees/g;
if ($result !~ s/SV_ACTION_ITEMS/$formattedActions/)
	{
	if ($result =~ s/SV_NEW_ACTION_ITEMS/$formattedActions/)
		{ &Warn("\nWARNING: Template format has changed.  SV_NEW_ACTION_ITEMS should now be SV_ACTION_ITEMS\n\n"); }
	else { &Warn("\nWARNING: SV_ACTION_ITEMS marker not found in template!\n\n"); } 
	}
$result =~ s/SV_AGENDA_BODIES/$all/;
$result =~ s/SV_MEETING_TITLE/$title/g if $title;

# Version
$result =~ s/SCRIBEPERL_VERSION/$CVS_VERSION/;

my $formattedLogURL = '<p>See also: <a href="SV_MEETING_IRC_URL">IRC log</a></p>';
if (!$logURL)
	{
	&Warn("\nWARNING: IRC log location not specified!  (You can ignore this \nwarning if you do not want the generated minutes to contain \na link to the original IRC log.)\n\n");
	$formattedLogURL = "";
	}
$formattedLogURL = "" if $logURL =~ m/\ANone\Z/i;
$result =~ s/SV_FORMATTED_IRC_URL/$formattedLogURL/g;
$result =~ s/SV_MEETING_IRC_URL/$logURL/g;

my $formattedAgendaLocation = '';
if ($agendaLocation) {
    $formattedAgendaLocation = "<p><a href='$agendaLocation'>Agenda</a></p>\n";
}
$result =~ s/SV_FORMATTED_AGENDA_LINK/$formattedAgendaLocation/g;

# Include DRAFT warning in minutes?
my $draftWarningHTML = '<h1> - DRAFT - </h1>';
$draftWarningHTML = '' if !$draft;
($result =~ s/SV_DRAFT_WARNING/$draftWarningHTML/g) || &Warn("\nWARNING: SV_DRAFT_WARNING not found in template.\nYou can ignore this warning if your minutes template does not\nneed a '- DRAFT -' warning.\n\n"); 

#### Output seems to be normally valid now.
# &Warn("\nWARNING: There is currently a bug that causes this program to\ngenerate INVALID HTML!  You can correct it by piping the output \nthrough \"tidy -c\".   If you have tidy installed, you can use \nthe -tidy option to do so.  Otherwise, run the W3C validator to find \nand fix the error: http://validator.w3.org/\n\n");

# Embed diagnostics in the generated minutes?
my $diagnosticsHTML = "<hr />
<h2>Scribe.perl diagnostic output</h2>
[Delete this section before finalizing the minutes.] <br>
<pre>\n" . &MakeLinks(&EscapeHTML($diagnostics)) . "\n</pre>
[End of <a href=\"http://dev.w3.org/cvsweb/~checkout~/2002/scribe/scribedoc.htm\">scribe.perl</a> diagnostic output]\n";
$diagnosticsHTML = '' if !$embedDiagnostics;
($result =~ s/SV_DIAGNOSTICS/$diagnosticsHTML/g) || warn "\nWARNING: SV_DIAGNOSTICS not found in template.\nYou can ignore this warning if your minutes template does not\nneed to contain scribe.perl's diagnostic output.\n\n";

# Done.
print $result;

exit 0;
################### END OF MAIN ######################

###########################################################
################# TempProcessEscapeHTML ####################
###########################################################
# TODO: Get rid of this function after converting to new processing model.
sub TempProcessEscapeHTML
{
@_ >= 4 || die;
my ($writer, $line, $all, $wholeLine) = @_;
# ($deltaDone, $line, $all) = &$lineProcessorRef($writer, $line, $all);
my $deltaDone = "";
$deltaDone .= &EscapeHTML($wholeLine) . "\n";
return ($deltaDone, "", $all);
}

###########################################################
################# ProcessNamedAnchors ####################
###########################################################
sub ProcessNamedAnchors
{
@_ >= 3 || die;
my ($writer, $line, $all) = @_;
# ($deltaDone, $line, $all) = &$lineProcessorRef($writer, $line, $all);
# GLOBAL my %globalProcessNamedAnchors_anchorIDs = ();
# Looking for:
# 	<inserted> NamedAnchorHere: action01
# if ($allLines[$i] !~ m/\A\&lt\;[^ \t\<\>\&]+\&gt\;\s*NamedAnchorHere\:\s*(\S+)\s*\Z/i)
# if ($line !~ m/\A($globalLTPattern$namePattern$globalGTPattern)?\s*NamedAnchorHere\:\s*(\S+)\s*\Z/i)
if ($line !~ m/\A(\<$namePattern\>)?\s*NamedAnchorHere\:\s*(\S+)\s*\Z/i)
	{
	return ("", $line, $all);
	}
# Found one.  Convert it to a real named anchor.
my $anchorID = $2;
# die if !defined($anchorID);
&Warn("WARNING: Duplicate named anchor: $anchorID\n") if (exists($globalProcessNamedAnchors_anchorIDs{$anchorID}));
$globalProcessNamedAnchors_anchorIDs{$anchorID} = $anchorID;
my $deltaDone = "<a name=\"$anchorID\"></a>\n";
# warn "ProcessNamedAnchors:\n  line: $line\n  deltaDone: $deltaDone\n";
return ($deltaDone, "", $all);
}

###############################################################
#################### ProcessScribeCommand #############################
###############################################################
# Format topic titles (i.e., collect agenda):
sub UNUSED_ProcessScribeCommand
{
@_ >= 4 || die;
my ($writer, $line, $all, $wholeLine) = @_;
if ($line !~ m/\A\s*Scribe\s*\:(.*)\Z/i)
	{
	return ("", $line, $all);
	}
my $who = &Trim($1);
# warn "SCRIBE: $who\n";
if ($who eq "")
	{
	&Warn("WARNING: Empty \"Scribe:\" command ignored.\n");
	return("", "", $all);
	}
# Check for scribe statement rather than the "Scribe:" command.
# Scribe: something that the scribe said
if ($who =~ m/\A\w+\s+\w+\s+\w+/) 	# 3 or more words
	{
	&Warn("WARNING: \"Scribe:\" command found with multiple words: $wholeLine\nEXPLANATION: The \"Scribe:\" command is used to indicate the name of the scribe.  Statements by the scribe should be minuted using the person's name, such as \"Alice: I favor option 2\".\n");
	# *** stopped here ***
	}
my $deltaDone = &FormatSpeakerParagraph($line);
return($deltaDone, "", $all);
}

###############################################################
#################### ProcessTopic #############################
###############################################################
# Format topic titles (i.e., collect agenda):
sub ProcessTopic
{
@_ >= 3 || die;
my ($writer, $line, $all) = @_;
# ($deltaDone, $line, $all) = &$lineProcessorRef($writer, $line, $all);
my $deltaDone = "";
# GLOBAL my @globalProcessTopic_agenda = ();
# GLOBAL my @globalProcessTopic_agendaIDs = ();
# GLOBAL my $globalProcessTopic_agenda = "";
# while ($all =~ s/\n(\&lt\;$namePattern\&gt\;\s+)?Topic\:\s*(.*)\n/\n$preTopicHTML id\=\"$ProcessTopic_itemNum\"\>$2$postTopicHTML\n/i)
# warn "LINE: $line\n";
# if ($line !~ m/\A(\<$namePattern\>)?\s*Topic\s*\:(.*)\Z/i)
if ($line !~ m/\A($globalLTPattern$namePattern$globalGTPattern)?\s*Topic\s*\:(.*)\Z/i)
	{
	return ("", $line, $all);
	}
my $topic = &Trim($2);
# warn "TOPIC: $topic\n";
if ($topic eq "")
	{
	&Warn("WARNING: Empty \"Topic:\" ignored.\n");
	return("", "", $all);
	}
my $n = scalar(@globalProcessTopic_agenda);
my $anchor = sprintf("item%02d", $n+1);
push(@globalProcessTopic_agenda, $topic);
push(@globalProcessTopic_agendaIDs, $anchor);
my $tocHTMLTemplate = "<li><a href=\"#\$anchor\">\$topic</a></li>\n";
# $oldGlobalAgenda .= '<li><a href="#' . $anchor . '">' . &EscapeHTML($topic) . "</a></li>\n";
my $tocItem = $tocHTMLTemplate;
my $escapedTopic = &EscapeHTML($topic); # Only escape special chars
$tocItem =~ s/\$anchor\b/$anchor/g;
$tocItem =~ s/\$topic\b/$escapedTopic/g;
$tocItem ne $tocHTMLTemplate || &Die("ERROR: Bad \$tocHTMLTemplate!\n");
$oldGlobalAgenda .= $tocItem;
my $topicHTMLTemplate = "<h3 id=\"\$anchor\">\$topic</h3>\n";
my $h = $topicHTMLTemplate;
my $hTopic = &ToHTML($topic); # make links of URLs
$h =~ s/\$anchor\b/$anchor/g;
$h =~ s/\$topic\b/$hTopic/g;
$h ne $topicHTMLTemplate || &Die("ERROR: Bad \$topicHTMLTemplate!\n");
$deltaDone = $h;
return($deltaDone, "", $all);
}

####################################################################
#################### ProcessActions ############################
####################################################################
sub ProcessActions
{
@_ >= 3 || die;
my ($writer, $line, $all) = @_;
# ($deltaDone, $line, $all) = &$lineProcessorRef($writer, $line, $all);
my $deltaDone = "";
if ($line !~ m/\A\s*ACTION\s*\:(.*)\Z/i)
	{
	return ("", $line, $all);
	}
my $action = &Trim($1);
my $ah = "<strong>ACTION:</strong> " . &ToHTML($action);
# warn "ACTION: $action\n";
# Highlight in-line ACTION status:
foreach my $status (@actionStatuses)
	{
	my $ucStatus = $status;
	$ucStatus =~ tr/a-z/A-Z/; # Make upper case but not preferred spelling
	##### Crude and may not always work:
	$ah =~ s/\[\s*$status\s*\]/<strong>[$ucStatus]<\/strong>/ig;
	}
# warn "FORMATTEDACTION: $ah";
$deltaDone = &FormatParagraph($writer, $ah);
return($deltaDone, "", $all);
}
# ******** stopped here ***********

###################################################################
####################### NextLine ##################################
###################################################################
# Grab next line from $all, skipping empty lines or statements.
# ($writer, $line, $nextAll, $wholeLine) = &NextLine($all);
sub NextLine
{
@_ == 1 || die;
my ($all) = @_;
defined($all) || die;
while (1)
	{
	return("", "", "", "") if $all eq "";
	my $wholeLine = "";
	$wholeLine = $1 if $all =~ s/\A(.*)(\n?)//;
	my $line = $wholeLine;
	my $writer = "";
	$writer = $1 if $line =~ s/\A\s?\s?\<($namePattern)\>[\ \t]?//;
	return ($writer, $line, $all, $wholeLine) if &Trim($line) ne "";
	}
}

###################################################################
####################### MapProcessLines ###########################
###################################################################
#### Experimenting with a different line processing model.
# For each line, try each function until one eats the line.
sub MapProcessLines
{
@_ > 1 || die;
my ($all, @functions) = @_;
my $done = "";
while ($all)		# Grab next line
	{
	my ($writer, $line, $nextAll, $wholeLine) = &NextLine($all);
	last if $line eq "";
	$all = $nextAll;
	# warn "LINE: $line\n";
	foreach my $f (@functions)
		{
		my $deltaDone = "";
		($deltaDone, $line, $all) = &$f($writer, $line, $all, $wholeLine);
		defined($all) || die;
		$done .= $deltaDone;
		last if $line eq "";
		}
	# Default if no function ate the line:
	if ($line ne "")
		{
		$done .= "$wholeLine\n";	
		# TODO: Apply &EscapeHTML and add <br> at the end of the line.
		# $done .= &EscapeHTML($wholeLine) . " <br>\n";
		}
	}
# print $done; exit 0;
#### TODO: Do we need the extra \n's any more?
# return("$done");
return("\n$done\n");
}

##############################################################
####################### ProcessRalphURL ##############
##############################################################
# Hide URLs when there is link text supplied in one of these formats:
# <RalphS> -> http://lists.w3.org/Archives/Team/w3t-mit/2005Jan/0052.html Philippe's two minutes
# <RalphS> [-> http://lists.w3.org/Archives/Team/w3t-mit/2005Mar/0113.html Ted's two minutes]
# (Per Ralph Swick's convention)
sub ProcessRalphURL
{
@_ >= 3 || die;
my ($writer, $line, $all) = @_;
# This also permits () {} around the line, in addition to [] or nothing.
($line =~ m/\A\s*([\[\{\(]?)\s*\-\>\s*($urlPattern)\s+(.*?)\s*([\]\}\)]?)\s*\Z/) || return("", $line, $all);
my $openBracket = $1;
my $url = $2;
my $title = $3;
my $closeBracket = $4;
my $lineHTML = &EscapeHTML($openBracket) . "<a href=\"$url\">" . &EscapeHTML($title) . "</a>" . &EscapeHTML($closeBracket);
my $deltaDone = &FormatParagraph($writer, $lineHTML);
# *** stopped here ***
return($deltaDone, "", $all);
}

##############################################################
####################### ProcessIRCStatement ##############
##############################################################
# This must be called last!  It is the default.
##### Convert:
# <Roy> Edinburgh +1
##### Into:
# <p class='irc'>
# &lt;<cite>Roy</cite>&gt; Edinburgh +1
# </p>
sub ProcessIRCStatement
{
@_ >= 3 || die;
my ($writer, $line, $all) = @_;
return("", $line, $all) if (!$writer);
#### TODO: Might want to join continuation lines in the future.
my $deltaDone = &FormatIRCParagraph($writer, &ToHTML($line));
return($deltaDone, "", $all);
}

##############################################################
####################### ProcessScribeStatement ##############
##############################################################
##### Convert:
# <DanC> VQ: recall we agreed to meet near Nice just after the W3C AC meeting...
# <DanC> ... and HT has offered to host...
# <DanC> ... some preferences each way...
##### Into:
# <p class='phone'>
# <cite>VQ:</cite> recall we agreed to meet near Nice just after the W3C AC meeting... <br>
# ... and HT has offered to host... <br>
# ... some preferences each way...
# </p>
sub ProcessScribeStatement
{
@_ >= 3 || die;
my ($writer, $line, $all) = @_;
return("", $line, $all) if $writer && &LC($writer) ne "scribe";
my $speakerHTML = "";
# VQ: recall we agreed to meet near Nice just after the W3C AC meeting...
if ($line =~ m/\A\s?\s?($speakerPattern)\s*\:\s*(.*?)\s*\Z/
  && !exists($stopList{&LC($1)}))
	{
	my $speaker = $1;
	# This will only work if $speakerPattern has no parens!!
	$line = $2; 
	my $speakerHTMLTemplate = "<cite>\$speaker\:</cite> ";
	$speakerHTML = $speakerHTMLTemplate;
	my $sh = &EscapeHTML($speaker);
	$speakerHTML =~ s/\$speaker/$sh/g;
	$speakerHTML ne $speakerHTMLTemplate || &Die("ERROR: Bad \$speakerHTMLTemplate!\n");
	# warn "SPEAKERHTML: $speakerHTML\n";
	}
# TODO: Delete the following "if" statement after converting to new proc model:
if ($line =~ m/\A\s?\s?($speakerPattern)\s*\:\s*(.*?)\s*\Z/
  && &LC($1) eq "scribe" 
  && m/\A\s?\s?Scribe\:\s*\w+\s+\w+\s+\w+/i)
	{
	my $speaker = $1;
	# This will only work if $speakerPattern has no parens!!
	$line = $2; 
	my $speakerHTMLTemplate = "<cite>\$speaker\:</cite> ";
	$speakerHTML = $speakerHTMLTemplate;
	my $sh = &EscapeHTML($speaker);
	$speakerHTML =~ s/\$speaker/$sh/g;
	$speakerHTML ne $speakerHTMLTemplate || &Die("ERROR: Bad \$speakerHTMLTemplate!\n");
	# warn "SPEAKERHTML: $speakerHTML\n";
	}
my $statementHTML = $speakerHTML . &ToHTML($line);
# Join continuation lines into this paragraph:
while (1)
	{
	my ($nextWriter, $nextLine, $nextAll) = &NextLine($all);
	# warn "NEXTWRITER: $nextWriter NEXTLINE: $nextLine\n";
	last if !$nextLine;
	last if $nextWriter && &LC($nextWriter) ne "scribe";
	last if $nextLine !~ m/\A\s?\s?\.\./;
	# ... Continuation
	$statementHTML .= " <br>\n" . &ToHTML($nextLine);
	$all = $nextAll;
	}
my $deltaDone = &FormatScribeParagraph($statementHTML);
# TODO: Delete the following special case after converting to new proc model:
$deltaDone = &FormatIRCParagraph($writer, &ToHTML($line)) 
	if $writer && $line =~ m/\A\s?\s?Scribe\:/i && $line !~ m/\A\s?\s?scribe\:\s*\w+\s+\w+\s+\s+/i;
# TODO: Delete the following special case after converting to new proc model:
$deltaDone = &FormatIRCParagraph($writer, &ToHTML($line)) 
	if $writer && $line =~ m/\A\s?\s?ScribeNick\:/i && $line !~ m/\A\s?\s?scribe\:\s*\w+\s+\w+\s+\s+/i;
# TODO: Delete the following special case after converting to new proc model:
if ($writer && $line =~ m/\A\W*$actionStatusesPattern\b/i)
	{ $deltaDone = &FormatIRCParagraph($writer, &ToHTML($line)); }
# warn "DELTADONE: $deltaDone\n";
return($deltaDone, "", $all);
}

################################################################
######################## CommandMeeting ########################
################################################################
# ***UNUSED***
# my @ucCommands = qw(Meeting Scribe ScribeNick Topic Chair 
# 	Present Regrets Agenda 
# 	IRC Log IRC_Log IRCLog Previous_Meeting PreviousMeeting ACTION);
sub CommandMeeting
{
@_ == 3 || die;
my ($writer, $line, $all) = @_;
($line =~ m/\A\s{0,4}Meeting\s{0,2}:\s*(.*)\s*\Z/i)
	|| return("", $line, $all);
my $t = &EscapeHTML(&Trim($1));
if ($t eq "") { &Warn("WARNING: Empty \"Meeting: title\" command with empty title\n"); }
# else { $globalMeetingTitle = $t; }
else { $title = $t; }
return("", "", $all);
}

####################################################################
###################### FormatSpeaker ################################
####################################################################
sub OLD_FormatSpeaker
{
@_ == 1 || die;
my ($speaker) = @_;
return("") if $speaker eq "";
my $speakerHTMLTemplate = "<cite>\$speaker</cite>\: ";
my $speakerHTML = $speakerHTMLTemplate;
my $sh = &EscapeHTML($speaker); # Just to be safe
$speakerHTML =~ s/\$speaker\b/$sh/g;
$speakerHTML ne $speakerHTMLTemplate || die;
return($speakerHTML);
}

####################################################################
###################### FormatWriter ################################
####################################################################
sub OLD_FormatWriter
{
@_ == 1 || die;
my ($writer) = @_;
return("") if $writer eq "";
my $writerHTMLTemplate = "&lt;<cite>\$writer</cite>&gt; ";
my $writerHTML = $writerHTMLTemplate;
my $sh = &EscapeHTML($writer); # Just to be safe
$writerHTML =~ s/\$writer\b/$sh/g;
$writerHTML ne $writerHTMLTemplate || die;
return($writerHTML);
}

####################################################################
###################### FormatParagraph ################################
####################################################################
# Format either a scribe or non-scribe (IRC) statement.
sub FormatParagraph
{
@_ == 2 || die;
my ($writer, $statementHTML) = @_;
if (($writer && &LC($writer) ne "scribe")
# TODO: Delete this special case after converting to new proc model:
  || ($writer && $statementHTML =~ m/\bACTION\b/))
	{ return(&FormatIRCParagraph($writer, $statementHTML)); }
else	{ return(&FormatScribeParagraph($statementHTML)); }
}

####################################################################
###################### FormatIRCParagraph ################################
####################################################################
# IRC statement -- normally a non-scribe statement.
sub FormatIRCParagraph
{
@_ == 2 || die;
my ($writer, $statementHTML) = @_;
my $ircParagraphHTMLTemplate = "<p class='irc'>\n&lt;<cite>\$writer</cite>&gt; \$statementHTML\n</p>\n\n";
my $ircParagraphHTML = $ircParagraphHTMLTemplate;
my $wh = &EscapeHTML($writer); # Be safe
$ircParagraphHTML =~ s/\$writer\b/$wh/g;
$ircParagraphHTML =~ s/\$statementHTML\b/$statementHTML/g;
$ircParagraphHTML ne $ircParagraphHTMLTemplate || &Die("ERROR: Bad \$ircParagraphHTMLTemplate!\n");
# &Warn("IRCPARAGRAPH: $ircParagraphHTML");
return($ircParagraphHTML);
}

####################################################################
###################### FormatScribeParagraph ################################
####################################################################
# Scribe statement.
sub FormatScribeParagraph
{
@_ == 1 || die;
my ($statementHTML) = @_;
my $scribeParagraphHTMLTemplate = "$prePhoneParagraphHTML\n\$statementHTML\n$postPhoneParagraphHTML\n\n";
my $scribeParagraphHTML = $scribeParagraphHTMLTemplate;
$scribeParagraphHTML =~ s/\$statementHTML\b/$statementHTML/g;
$scribeParagraphHTML ne $scribeParagraphHTMLTemplate || &Die("ERROR: Bad \$scribeParagraphHTMLTemplate!\n");
return($scribeParagraphHTML);
}

################################################################
########################## ToHTML ##############################
################################################################
# Convert text to HTML, escaping special chars and making anchors
# of URLs as needed.
sub ToHTML
{
@_ == 1 || die;
my ($t) = @_;
my $done = "";	# Resulting HTML
# Hmm, should Ralph URL also be processed here?  No, better to process that
# as a line command.
# Process URLs:
while ($t =~ m/\A((.|\n)*?)($urlPattern)/)
	{
	my $pre = $1;
	my $url = $3;
	my $post = $';
	my $h = &EscapeHTML($pre);
	$h .= "<a href=\"$url\">" . &EscapeHTML($url) . "</a>";
	$done .= $h;
	$t = $post;
	}
$done .= &EscapeHTML($t); # Remainder
return($done);
}

###############################################################
##################### ProcessEdits ####################
###############################################################
# Preprocess to perform s/old/new/ substitutions
# and i/where/line/ insertions.
# This needs to be done as a global preprocessing step because it
# affects earlier lines.
sub ProcessEdits
{
@_ == 1 || die;
my ($all) = @_;
# Perform s/old/new/ substitutions.
# 5/11/04: dbooth changed this to be first to last, because that's
# what users expect.
my $done = "";
$all = "\n$all\n"; # Ensure easy pattern matching
# while($all =~ m/\A((.|\n)*?)(\n(\<[^\>]+\>)\s*s\/([^\/]+)\/([^\/]*?)((\/(g))|\/?)(\s*))\n/i)
while($all =~ m/\A((.|\n)*?)(\n(\<[^\>]+\>)\s*(s|i)(\/|\|)(.*))\n/)
	{
	my $pre = $1;
	my $match = $3; # Begins with \n but none on the end
	my $who = $4;
	my $cmd = $5;
	my $delimiter = $6;
	my $delimP = quotemeta($delimiter);
	my $rest = $7;
	my $wholeMatch = $&; # The whole thing, including ending \n
	my $post = $';
	my $notDelimP = "[^$delimP]";
	"$pre$match\n" eq $wholeMatch || die; # Guard
	$rest =~ s/\s+\Z//;	# Trim trailing spaces
	# s/old/new/ command?
	# warn "DEBUG ProcessEdits: match: $match who: $who cmd: $cmd delimiter: $delimiter delimP: $delimP rest: $rest\n";
	if ($cmd eq "s" && $rest =~ m/\A(($notDelimP)+)$delimP(($notDelimP)*)($delimP([gG]?))?\Z/)
		{
		my $old = $1;
		my $new = $3;
		# &Warn("DEBUG NEW: $new\n");
		my $global = $6;
		$global = "" if !defined($global);
		my $oldp = quotemeta($old);
		# warn "Found match: $match\n";
		my $told = $old;
		$told = $& . "...(truncated)...." if ($old =~ m/\A.*\n/);
		my $tnew = $new;
		$tnew = $& . "...(truncated)...." if ($old =~ m/\A.*\n/);
		# my $tall = $pre . "\n" . $post;
		# s/old/new/g  replaces globally from this point backward
		my $allPre = $done . $pre;
		my $tPost = $post;
		my $singleAllPre = $allPre;
		# Precompute the results of substitutions, then select the
		# right results depending on the options specified.
		# Global substitution from this point back:
		my $allPreMatched = ($allPre =~ s/$oldp/$new/g);
		# Global substitution from this point forward:
		my $tPostMatched =  ($tPost =~ s/$oldp/$new/g);
		# Single, most recent substitution:
		my $singleAllPreMatched = ($singleAllPre =~ s/\A((.|\n)*)($oldp)((.|\n)*?)\Z/$1$new$4/);
		# warn "a t s: $allPreMatched $tPostMatched $singleAllPreMatched\n";
		# if (($global eq "g")  && $allPre =~ s/$oldp/$new/g)
		if (($global eq "g")  && $allPreMatched)
			{
			&Warn("Succeeded: s$delimiter$told$delimiter$tnew$delimiter$global\n");
			# $all = $pre . "\n" . $post;
			$done = $allPre;
			$all = "\n" . $post;
			}
		# s/old/new/G  replaces globally, both forward and backward
		# elsif (($global eq "G")  && $tall =~ s/$oldp/$new/g)
		# elsif (($global eq "G")  && (($allPre =~ s/$oldp/$new/g) || ($tPost =~ s/$oldp/$new/g)))
		elsif (($global eq "G")  && ($allPreMatched || $tPostMatched))
			{ 
			&Warn("Succeeded: s$delimiter$told$delimiter$tnew$delimiter$global\n");
			# $all = $tall;
			$done = $allPre;
			$all = "\n" . $tPost;
			}
		# s/old/new/  replaces most recent occurrance of old with new
		# elsif ((!$global) && $allPre =~ s/\A((.|\n)*)($oldp)((.|\n)*?)\Z/$1$new$4/)
		elsif ((!$global) && $singleAllPreMatched)
			{
			&Warn("Succeeded: s$delimiter$told$delimiter$tnew$delimiter$global\n");
			# $all = $pre . "\n" . $post;
			$done = $singleAllPre;
			$all = "\n" . $post;
			}
		else	{
			&Warn("FAILED: s$delimiter$told$delimiter$tnew$delimiter$global\n");
			$done .= $pre . $match; # Does not end with \n
			$all = "\n$post";
			}
		&Warn("\nWARNING: Multiline substitution!!! (Is this correct?)\n\n") if $tnew ne $new || $told ne $old;
		}
	# while($all =~ m/\A((.|\n)*?)(\n(\<[^\>]+\>)\s*i\/([^\/]+)\/(.*))\n/)
	elsif ($cmd eq "i" && $rest =~ m/\A(($notDelimP)+)$delimP(.*)\Z/)
		{
		my $locationString = $1; # Where to insert the new line
		my $newLine = $3;	# Line to be inserted
		my $donePre = $done . $pre;
		$newLine =~ s/$delimP\Z//;	# Remove any trailing /
		my $locationPattern = quotemeta($locationString);
		my $told = $locationString;
		$told = $& . "...(truncated)...." if ($locationString =~ m/\A.*\n/);
		my $tnew = $newLine;
		$tnew = $& . "...(truncated)...." if ($newLine =~ m/\A.*\n/);
		# warn "DEBUG locationString: $locationString locationPattern: $locationPattern newLine: $newLine\n";
		if ($donePre =~ m/\A((.|\n)*\n)((.*)($locationPattern)(.*))((\n((.|\n)*?))?)\Z/)
			{
			my $preLines = $1;	# Ends with \n
			my $postLines = $7;	# Starts with \n
			my $matchingLine = $3; 	# Has no \n
			&Warn("Succeeded: i$delimiter$told$delimiter$tnew\n");
			# $all = $preLines . "<inserted> $newLine\n$matchingLine" . $postLines . "\n" . $post;
			$done = $preLines . "<inserted> $newLine\n$matchingLine" . $postLines;
			$all = "\n$post";
			}
		else	{
			# die "DEBUG locationString: $locationString locationPattern: $locationPattern newLine: $newLine donePre: $donePre\n";
			&Warn("FAILED: i$delimiter$told$delimiter$tnew\n");
			$done .= $pre . $match; # Does not end with \n
			$all = "\n$post";
			}
		&Warn("\nWARNING: Multiline i// insertion!!! (Is this correct?)\n\n") if $tnew ne $newLine || $told ne $locationString;
		}
	else	{
		# Not a logal s/// or i/// command.
		$done .= $pre . $match; # Does not end with \n
		$all = "\n$post";
		&Warn("WARNING: Bad $cmd$delimiter$delimiter$delimiter command: $cmd$delimiter$rest\n");
		}
	}
$all = $done . $all;
# print $all;
# die;
return($all);
} # End of ProcessEdits


#######################################################################
###################### GetActions #################################
#######################################################################
######### Action processing
######### ACTION processing
######### ACTION Item Processing
sub GetActions
{
@_ == 1 || die;
my ($all) = @_;
# Declared: @lines %debugTypesSeen %rrsagentActions @rrsagentLines 
# %otherActions %rawActions %statusPatterns %actions %actionPeople 
# $actionTemplate @formattedActionLines $formattedActions 
# First put all action items into a common format, to make them easier to process.
my @lines = split(/\n/, $all);
my %debugTypesSeen = ();
for (my $i=0; $i<(@lines-1); $i++)
	{
	# $debugActions = ($lines[$i] =~ m/Guus2/) ? 1 : 0;
	warn "\nLINE: " . $lines[$i] . "\n" if $debugActions;
	# warn "\nAFTER GUUS2: " . $lines[$i+1] . "\n" if $debugActions;
	if (1)
		{
		# Handle alternate syntax permitted by RRSAgent:
		# 	ACTION dbooth: fix this bug
		# Convert it to:
		# 	ACTION: dbooth to fix this bug
		# The regex in RRSAgent is currently:
		# 	^\s*(?:ACTION\s*|action\s*)(?:(\w+)\s*|)(:)\s*(.*)$
		# However, Ralph mentioned that if it were expanded to permit
		# multiple people then names would be comma separated, so
		# we'll allow for that here, even though I don't like 
		# this alternate action syntax, because it's different from
		# the syntax of all other commands.
		die if !defined($lines[$i]);
		my ($writer, undef, undef, undef, $allButWriter) = &ParseLine($lines[$i]);
		if ($allButWriter =~ m/\A\s*ACTION\s+((\w+)(\s*\,\s*\w+)*)\s*\:\s*/i)
			{
			my $actionee = $1;
			my $task = $';
			$task =~ s/\Ato //;	# Prevent duplicate "to"
			# warn "Found new action syntax: actionee: $actionee task: $task\n";
#@@			$task = &EscapeHTML($task);
			$lines[$i] = "<$writer> ACTION: $actionee to $task";
			# warn "Normalized: $lines[$i]\n";
			}
		}

	# First move the status out from in front of ACTION,
	# so that ACTION is always at the beginning.
	# Convert lines like: 
	#	[PENDING] ACTION: whatever
	# into lines like:
	#	ACTION: [PENDING] whatever
	if (1)
		{
		die if !defined($lines[$i]);
		my ($writer, $type, $value, $rest, undef) = &ParseLine($lines[$i]);
		my ($writer2, $type2, $value2, $rest2, undef) = &ParseLine("<scribe> $rest");
		while ($type2 eq "STATUS")
			{
			# Ignore nested status:
			#	[PENDING] [NEW] ACTION: whatever
			($writer2, $type2, $value2, $rest2, undef) = &ParseLine("<scribe> $rest2");
			}
		$debugTypesSeen{$type}++;
		warn "LINETYPE writer: $writer type: $type value: $value rest: $rest\n" if $debugActions && $debugTypesSeen{$type} < 3;
		if ($type eq "STATUS" && $type2 eq "COMMAND" && $value2 eq "action")
			{
			$lines[$i] = "<$writer\> ACTION: \[$value\] $rest2";
			warn "MOVED: $lines[$i]\n" if $debugActions;
			}
		}

	if (1)
		{
		# Now join ACTION continuation lines.  Convert lines like:
		#	<dbooth> ACTION: Mary to buy
		#	<dbooth>   the ingredients.
		# to this:
		#	<dbooth> ACTION: Mary to buy the ingredients.
		# It might be better if the continuation line processing was
		# done only once, globally, instead of doing it separately here
		# for actions.
		die if !defined($lines[$i]);
		my ($writer, $type, $value, $rest, undef) = &ParseLine($lines[$i]);
		die if !defined($lines[$i+1]);
		my ($writer2, $type2, $value2, $rest2, undef) = &ParseLine($lines[$i+1]);
		$debugTypesSeen{$type}++;
		warn "LINETYPE writer: $writer type: $type value: $value rest: $rest\n" if $debugActions && $debugTypesSeen{$type} < 3;
		if ($type eq "COMMAND" && $value eq "action"
			&& &LC($writer2) eq &LC($writer)
			&& ($type2 eq "CONTINUATION"))
			{
			$lines[$i] = "";
			$lines[$i+1] = "<$writer\> ACTION: $rest $rest2";
			warn "JOINED ACTION CONTINUATION: " . $lines[$i+1] . "\n" if $debugActions;
			}
		#### Commented out this branch, since I think it is handled
		#### below anyway.
		elsif (0 && $type eq "COMMAND" && $value eq "action"
			&& &LC($writer2) eq &LC($writer)
			&& ($type2 eq "STATUS"))
			{
			my $cont = "\[$value2\] $rest2"; 
			$lines[$i] = "";
			$lines[$i+1] = "<$writer\> ACTION: $rest $cont";
			warn "JOINED: " . $lines[$i+1] . "\n" if $debugActions;
			}

		}

	if (1)
		{
		# Now look for status on lines following ACTION lines.
		# This only works if we are NOT using RRSAgent's recorded actions.
		# Join line pairs like this:
		#	<dbooth> ACTION: whatever
		#	<dbooth> *DONE*
		# to lines like this:
		#	<dbooth> ACTION: whatever [DONE]
		die if !defined($lines[$i]);
		my ($writer, $type, $value, $rest, undef) = &ParseLine($lines[$i]);
		if ($type eq "COMMAND" && $value eq "action" && $i+1<@lines)
			{
			warn "FOUND ACTION: $rest\n" if $debugActions;
			# Look ahead at the next line (by anyone).
			die if !defined($lines[$i+1]);
			my ($writer2, $type2, $value2, $rest2, undef) = &ParseLine($lines[$i+1]);
			warn "type2: $type2 rest2: $rest2\n" if $debugActions;
			if ($type2 eq "STATUS" && $rest2 eq "")
				{
				$lines[$i] = "<$writer\> ACTION: $rest \[$value2\]";
				warn "JOINED NEXT SPEAKER LINE: " . $lines[$i+1] . "\n" if $debugActions;
				warn "RESULT: " . $lines[$i] . "\n" if $debugActions;
				$lines[$i+1] = "";
				# Delete the status line:
				@lines = @lines[0..$i,($i+2)..$#lines];
				# Reprocess this line:
				$i--;
				next;
				}
			else
				{
				# Didn't find status on next line. 
				# Look ahead at the next line by the same writer.
				for (my $j=$i+2; $j<@lines; $j++)
					{
					die if !defined($lines[$j]);
					my ($writer2, $type2, $value2, $rest2, undef) = &ParseLine($lines[$j]);
					last if ($type eq "COMMAND" && $value eq "action");
					if (&LC($writer2) eq &LC($writer))
						{
						if ($type2 eq "STATUS" && $rest2 eq "")
							{
							$lines[$i] = "<$writer\> ACTION: $rest \[$value2\]";
							$lines[$j] = "";
							warn "JOINED NEXT SPEAKER LINE: " . $lines[$i+1] . "\n" if $debugActions;
							}
						last;
						}
					}
				}
			}
		}

	if (1)
		{
		# Now grab the URL where the action was recorded.
		# Join line pairs like this:
		# 	<RRSAgent> ACTION: Simon develop ssh2 migration plan [1]
		# 	<RRSAgent>   recorded in http://www.w3.org/2003/09/02-mit-irc#T14-10-24
		# to lines like this:
		# 	<RRSAgent> ACTION: Simon develop ssh2 migration plan [1] [recorded in http://www.w3.org/2003/09/02-mit-irc#T14-10-24]
		die if !defined($lines[$i]);
		my ($writer, $type, $value, $rest, undef) = &ParseLine($lines[$i]);
		die if !defined($lines[$i+1]);
		my ($writer2, $type2, $value2, $rest2, undef) = &ParseLine($lines[$i+1]);
		if ($type eq "COMMAND" && $value eq "action"
			&& &LC($writer) eq "rrsagent" && 
			&LC($writer2) eq &LC($writer)
			&& $rest2 =~ m/\A\W*(recorded in http\:[^\s\[\]]+)(\s*\W*)\Z/i)
			{
			my $recorded = $1;
			$lines[$i] = "";
			$lines[$i+1] = "<$writer\> ACTION: $rest \[$recorded\]";
			warn "JOINED RECORDED: " . $lines[$i+1] . "\n" if $debugActions;
			}
		}
	}
$all = "\n" . join("\n", grep {$_} @lines) . "\n";

# Add a link from each action item to the place in the minutes (or log)
# where it was recorded, so that it is each to find the context of
# each action.
# We do this by adding a named anchor before each ACTION, and appending
# always points back to its original context.  
# We do this by adding a line before each ACTION line:
# 	<inserted> NamedAnchorHere: action1
# and appending " [recorded in http://...#action1]" to the end of
# the action.  (Or just " [recorded in http://...]" if we only
# know the $logURL and not the $minutesURL.)
if (1)
	{
	my @lines = split(/\n/, $all);
	my $actionID = "action01";
	for (my $i=0; $i<@lines; $i++)
		{
		next if $lines[$i] =~ m/^\<RRSAgent\>/i;
		next if $lines[$i] !~ m/\A\<[^\>]+\>\s*ACTION\s*\:\s*(.*?)\s*\Z/i;
		my $a = $lines[$i];
		# warn "FOUND ACTION: $a\n";
		my $pre = "<inserted> NamedAnchorHere: $actionID\n";
		# Default to no URL at all:
		my $post = "";
		# Or use the $logURL (with no frag ID) if there is one:
		$post = " [recorded in $logURL]" if $logURL;
		# But preferably Use $minutesURL with frag ID if we have one:
		$post = " [recorded in $minutesURL" . "#" . $actionID . "]"
			if $minutesURL;
		# Only add " [recorded in ...]" if the action does NOT 
		# already have it:
		$post = "" if $lines[$i] =~ m/\brecorded\s+in\s+http(s?)\:/;
		$lines[$i] = $pre . $lines[$i] . $post;
		$actionID++; 	# Perl string increment: action02, ....
		$a = $lines[$i];
		# warn "ADDED NamedAnchorHere: $a\n";
		}
	$all = "\n" . join("\n", @lines) . "\n";
	}

# Now it's time to collect the action items.
# Grab the action items both ways (from RRSAgent, and not from RRSAgent),
# so that we can generate a warning if we find them one way but not the other.
# We are initially sloppy about the action text we collect, because we
# will later clean it up and parse out the status and URL.
#
# First grab RRSAgent actions.
my %rrsagentActions = ();	# Actions according to RRSAgent
my @rrsagentLines = grep {m/^\<RRSAgent\>/} split(/\s*\n/, $all);
for (my $i = 0; $i <= $#rrsagentLines; $i++) {
	$_ = $rrsagentLines[$i];
	# <RRSAgent> I see 3 open action items:
	if (m/^\<RRSAgent\> I see \d+ open action items\:$/) {
	    # Start again
	    %rrsagentActions = ();
	    next;
	}
	# <RRSAgent> ACTION: Simon develop ssh2 migration plan [1]
	next unless (m/\<RRSAgent\> ACTION\: (.*)$/);
	my $action = "$1";
	$rrsagentActions{$action} = "";	# Unknown status (will default to NEW)
	warn "RRSAgent ACTION: $action\n" if $debugActions;
}

# Now grab actions the old way (not the RRSAgent lines).
my %otherActions = ();		# Actions found in text (not according to RRSAgent)
foreach my $line (split(/\n/,  $all))
	{
	next if $line =~ m/^\<RRSAgent\>/i;
	next if $line !~ m/\A\<[^\>]+\>\s*ACTION\s*\:\s*(.*?)\s*\Z/i;
	my $action = $1;
	warn "OTHER ACTION: $action\n" if $debugActions;
	$otherActions{$action} = "";
	}

# Which set of actions should we keep?
my %rawActions = ();	# Maps action to status (NEW|DONE|PENDING...)
if ($trustRRSAgent) {
	if (((keys %rrsagentActions) == 0) && ((keys %otherActions) > 0)) 
		{ &Warn("\nWARNING: No RRSAgent-recorded actions found, but 'ACTION:'s appear in the text.\nSUGGESTED REMEDY: Try running WITHOUT the -trustRRSAgent option\n\n"); }
	%rawActions = %rrsagentActions;
	&Warn("Using RRSAgent ACTIONS\n") if $debugActions;
} else {
	%rawActions = %otherActions;
	&Warn("Using OTHER ACTIONS\n") if $debugActions;
}

my %statusPatterns = ();	# Maps from a status to its regex.
foreach my $s (@actionStatuses)
	{
	die if $s !~ m/[a-zA-Z\_]/; # Canonical status, only letters/underscore
	my $p = quotemeta($s);
	# For multi-word status,
	# allow the user to write space or dash instead of underscore.
	# Accept as equivalent: IN_PROGRESS, IN PROGRESS, IN-PROGRESS 
	$p =~ s/\_/\[\\-\\_\\s\]\+/g; # Make _ into a pattern: [\_\-\s]+
	# warn "s: $s p: $p\n";
	$statusPatterns{$s} = $p;
	}

# Now clean up each action item and parse out its status and URL.
my %actions = ();
warn "Cleaning up each action and parsing status and URL...\n" if $debugActions;
foreach my $action ((keys %rawActions))
	{
	my $a = $action;
	next if !$a;
	my $status = "";
	my $url = "";
	my $olda = "";
	# Grab stuff off the ends as long as there is stuff to grab.
	# We do this in a loop to allow them to appear in any order.
	# However, we process them in a particular order within this
	# loop to give precedence to the status that the scribe wrote last,
	# but precedence to the URL that was recorded first.
	CHANGE: while ($a ne $olda)
		{
		warn "OLD a: $olda\n" if $debugActions;
		warn "NEW a: $a\n\n" if $debugActions;
		$olda = $a;
		$a = &Trim($a);
		next CHANGE if $a =~ s/\s*\[\d+\]?\s*\Z//;	# Delete action numbers: [4] [4
		next CHANGE if $a =~ s/\AACTION\s*\:\s*//i;	# Delete extra ACTION:
		# Grab URL from end of action.   
		# Innermost URL takes precedence if specified more than once.
		# This is not precisely the official URI pattern.
		my $urlp = "http\:[\#\%\&\*\+\,\-\.\/0-9\:\;\=\?\@-Z_a-z]+";
		if ($a =~ s/\s*\[?\s*recorded in ($urlp)\s*(\]?\s*)\Z//i)
			{
			$url = $1;
			warn "CLEANING ACTIONS GOT URL: $url\n" if $debugActions;
			next CHANGE;
			}
		foreach my $s (@actionStatuses)
			{
			my $p = $statusPatterns{$s};
			# Grab status from end of action.
			# Outermost status takes precedence if 
			# status appears more than once.
			# Note that this may whack off the right bracket
			# From the action number:
			# 	OLD a: Hugo inprog3 action [4] -- IN PROGRESS
			# 	NEW a: Hugo inprog3 action [4
			if ($a =~ s/[\*\(\[\-\=\s\:\;]+($p)[\*\)\]\-\=\s]*\Z//i)
				{
				$status = $s if !$status;
				warn "status: $status\n" if $debugActions;
				next CHANGE;
				}
			}
		foreach my $s (@actionStatuses)
			{
			my $p = $statusPatterns{$s};
			# Grab status from beginning of action.
			if ($a =~ s/\A[\*\(\[\-\=\s]*($p)[\*\)\]\-\=\s\:\;]+//i)
				{
				$status = $s if !$status;
				warn "status: $status\n" if $debugActions;
				next CHANGE;
				}
			}
		}
	# Put the URL back on the end
	$a .= " [recorded in $url]" if $url;
	$status = "NEW" if !$status;
	# Canonicalize action statuses:
	die if !exists($actionStatuses{&LC($status)});
	$status = $actionStatuses{&LC($status)}; # Map to preferred spelling
	warn "FINAL: [$status] $a\n\n" if $debugActions;
	$actions{$a} = $status;
	}

# Get a list of people who have current action items:
my %actionPeople = ();
warn "Getting list of action people...\n" if $debugActions;
foreach my $key ((keys %actions))
	{
	my $a = &LC($key);
	warn "action:$a:\n" if $debugActions;
	# Skip completed action items.  Check the status.
	die if !exists($actions{$key});
	my $lcs = &LC($actions{$key});
	# my %closedActionStatuses = map {($_,$_)} 
	# 	qw(done finished dropped completed retired deleted);
	next if exists($lcClosedActionStatuses{$lcs});
	# Remove leading date:
	#	ACTION: 2003-10-09: Bijan to look into message extensibility Issues
	#	ACTION: 10/09/03: Bijan to look into message extensibility Issues
	#	ACTION: 10/9: Bijan to look into message extensibility Issues
	$a =~ s/\A\d+[\-\/]\d+(([\-\/]\d+)?)(\:?)\s*//i;
	# Look for action recipients
	my @names = ();
	my @good = ();
	if ($a =~ m/\s+(to)\s+/i)
		{
		my $list = $`;
		@names = grep {&LC($_) ne "and"} split(/[^a-zA-Z0-9\-\_\.]+/, $list);
		# warn "names: @names\n";
		foreach my $n (@names)
			{
			next if $n eq "";
			$n = &LC($n);
			push(@good, $n) if !exists($stopList{$n});
			}
		@good = () if @good != @names; # Fail
		}
	if ((!@good) && $a =~ m/\A([a-zA-Z0-9\-\_\.]+)/i)
		{
		my $n = $1;
		@names = ($n);
		push(@good, $n) if !exists($stopList{$n});
		}
	# All good?
	if (@good && @good == @names)
		{
		foreach my $n (@good)
			{
			$actionPeople{$n} = $n;
			}
		}
	else	{
		&Warn("\nWARNING: No person found for ACTION item: $a\n\n");
		}
	}
&Warn("People with action items: ",join(" ", sort keys %actionPeople), "\n");

# Format the resulting action items.
# Iterate through the @actionStatuses in order to group them by status.
warn "Formatting the resulting action items....\n" if $debugActions;
warn "ACTIONS:\n" if $debugActions;
# my $actionTemplate = "<strong>[\$status]</strong> <strong>ACTION:</strong> \$action <br />\n";
my $actionTemplate = "[\$status] ACTION: \$action\n";
my @formattedActionLines = ();
foreach my $status (@actionStatuses)
	{
	my $n = 0;
	my $ucStatus = $actionStatuses{$status};
	foreach my $action (&CaseInsensitiveSort(keys %actions))
		{
		die if !exists($actions{$action});
		die if !defined($status);
		next if &LC($actions{$action}) ne &LC($status);
		my $s = $actionTemplate;
		my $escapedAction = EscapeHTML($action);
		$s =~ s/\$action/$escapedAction/;
		$s =~ s/\$status/$ucStatus/;
		push(@formattedActionLines, $s);
		$n++;
		delete($actions{$action});
		}
	push(@formattedActionLines, "\n") if $n>0;
	}
# There shouldn't be any more kinds of actions, but if there are, format them.
# $actions{'FAKE ACTION TEXT'} = 'OTHER_STATUS';	# Test
warn "Formatting remaining action items....\n" if $debugActions;
foreach my $status (sort values %actions)
	{
	my $n = 0;
	my $ucStatus = $actionStatuses{$status}; # Map to preferred spelling
	# foreach my $action (sort keys %actions)
	foreach my $action (&CaseInsensitiveSort(keys %actions))
		{
		die if !exists($actions{$action});
		die if !defined($status);
		next if &LC($actions{$action}) ne &LC($status);
		my $s = $actionTemplate;
		my $escapedAction = EscapeHTML($action);
		$s =~ s/\$action/$escapedAction/;
		$s =~ s/\$status/$ucStatus/;
		push(@formattedActionLines, $s);
		$n++;
		delete($actions{$action});
		}
	push(@formattedActionLines, "\n") if $n>0;
	}

# Try to break lines over 67 chars:
warn "Breaking lines over 67 chars....\n" if $debugActions;
@formattedActionLines = map { &WrapLine($_) } @formattedActionLines
	if $breakActions;
# Convert the @formattedActionLines to HTML.
# Add HTML line break to the end of each line:
@formattedActionLines = map { s/\n/ <br \/>\n/; $_ } @formattedActionLines;
# Change initial space (for continuation lines) to &nbsp;
@formattedActionLines = map { s/\A /\&nbsp\;/; $_ } @formattedActionLines;

my $formattedActions = join("", @formattedActionLines);
# Make links from URLs in actions:
warn "Making links in actions....\n" if $debugActions;
$formattedActions =~ s/(http\:([^\)\]\}\<\>\s\"\']+))/<a href=\"$1\">$1<\/a>/ig;

return( $all, $formattedActions );
} # End of GetActions


############################################################################
######################## GuessMinutesURL ##################################
############################################################################
sub GuessMinutesURL
{
@_ == 1 || die;
my ($all) = @_;
$all = "\n$all\n"; # Permit Easier pattern matching below
# <RRSAgent> I have made the request to generate http://www.w3.org/2005/02/10-ws-desc-minutes dbooth
if ($all =~ m/\n\<RRSAgent\>\s*I\s+have\s+made\s+the\s+request\s+to\s+generate\s+(http\:\S+)\s+/i)
	{
	my $url = $1;
	# warn "Found minutesURL: $url\n";
	return($url);
	}
return("");
}

#########################################################
################### MakeLinks #####################
#########################################################
# Convert URLs into links.  This is called *after* HTML special symbols
# have been escaped, such as <dbooth> to &lt;dbooth&gt;.
# MakeURLs
sub New_MakeLinks
{
@_ == 1 || die;
my ($all) = @_;
# Test input: test-data/22-tag*
#*** stopped here ***  UNFINISHED
# ************
# Make links:
my @lines = split(/\n/, $all);
my $preWriterPattern = quotemeta($preWriterHTML);
my $postWriterPattern = quotemeta($postWriterHTML);
for (my $i=0; $i<@lines; $i++)
	{
	next if $lines[$i] !~ m/\-\&gt\;/; # debug
	warn "URL LINE: $lines[$i]\n" if $lines[$i] =~ m/$urlPattern/;
	# Check for Ralph's link text syntax.  Example:
	# <RalphS> -> http://lists.w3.org/Archives/Team/w3t-mit/2005Jan/0052.html Philippe's two minutes
	# would have already been escaped to one of:
	# &lt;RalphS&gt; -&gt; http://lists.w3.org/Archives/Team/w3t-mit/2005Jan/0052.html Philippe's two minutes
	# &lt;<cite>RalphS</cite>&gt; -&gt; http://lists.w3.org/Archives/Team/w3t-mit/2005Jan/0052.html Philippe's two minutes
	# -&gt; http://lists.w3.org/Archives/Team/w3t-mit/2005Jan/0052.html Philippe's two minutes
	###### Big mess trying to match the <RalphS> part, so don't bother.
	# if ($ralphLinks && $lines[$i] =~ m/\A(\&lt\;$preWriterPattern[^\&\<\>]+$postWriterPattern\&gt\;)(\s*)\-\>\s*(\<?)($urlPattern)(\>?)\s*(\S+)\s*\Z/)
	# -&gt; http://www.w3.org/2005/02/07-tagmem-minutes.html minutes 7 Feb
	# if ($ralphLinks && $lines[$i] =~ m/(\s)\-\&gt\;\s*((\&lt\;)?)($urlPattern)((\&gt\;)?)\s*(\S+)\s*\Z/)
	if ($ralphLinks && $lines[$i] =~ m/()\-\&gt\;\s*((\&lt\;)?)($urlPattern)((\&gt\;)?)\s*(\S+)\s*\Z/)
	# if ($ralphLinks && $lines[$i] =~ m/(\s)\-\&gt\;\s*(())($urlPattern)(())\s*(\S+)\s*\Z/)
	# if ($ralphLinks && $lines[$i] =~ m/()\-\&gt\;\s*(())($urlPattern)(())\s*(\S+)\s*\Z/)
	# if ($ralphLinks && $lines[$i] =~ m/()(())($urlPattern)(())()\Z/)
		{
		my $pre = $`;
		my $spaces = $1;
		my $url = $4;
		my $title = $10;
		warn "RalphLink spaces: $spaces url: $url title: $title\n";
		$title = s/\A\"(.+)\"\Z/$1/;
		$title = s/\A\'(.+)\'\Z/$1/;
		my $newLine = "$pre$spaces<a href=\"$url\">$title</a>";
		warn "   newLine: $newLine\n";
		$lines[$i] = $newLine;
		}
	else	{
		my $allLine = $lines[$i];
		my $done = "";
		while ($allLine =~ m/\A((.|\n)*?)($urlPattern)(.*?)\n/)
			{
			my $pre = $1;
			my $url = $3;
			# $urlPattern has 3 parens:
			my $line = $7; # To end of line
			my $post = "\n" . $';
			if (1)	
				{
				#### TODO: Delete after conversion to new processing model
				if ($pre =~ m/\<a href\=\"($urlPattern)\Z/
				  && $line =~ m/\A\"\>($urlPattern)\<\/\a\>/)
					{
					# Ignore URL that is already a link
					$done .= $pre . $&;
					$allLine = $' . $post;
					}
				}
			die if !defined($line);
			if ($debug || 1)
				{
				my $t = $pre;
				$t =~ s/\A(.|\n)*\n//;
				$line = "" if !defined($line);
				warn "pre: $t url:$url line:$line|\n";
				}
			my $newpre = $pre;
			# Any other URL
			my $link = "<a href=\"$url\">$url</a>";
			$done .= $pre . $link;
			$allLine = $line . $post;
			}
		$done .= $all;
		$allLine = $done;
		$lines[$i] = $allLine;
		}
	}
$all = join("\n", @lines);
return($all);
}

#########################################################
################### OLD_MakeLinks #####################
#########################################################
# Convert URLs into links.
# OLD_MakeURLs
# This is really messy, because it assumes that $all is has already
# been &EscapeHTML()'d.  Thus, a link containing an & like
#
# appears as
#
sub MakeLinks
{
@_ == 1 || die;
my ($all) = @_;
# URL pattern from http://www.stylusstudio.com/xmldev/200108/post60960.html 
# my $anyUriPattern = '(([a-zA-Z][0-9a-zA-Z+\\-\\.]*:)?/{0,2}[0-9a-zA-Z;/?:@&=+$\\.\\-_!~*\'()%]+)?(#[0-9a-zA-Z;/?:@&=+$\\.\\-_!~*\'()%]+)?';
# $anyUriPattern is too general for our use.   We want to recognize 
# only http:// or https:// absolute URLs.
# 3 parens:
my $urlPattern = '(http(s?)://[0-9a-zA-Z;/?:@&=+$\\.\\-_!~*\'\(\)%]+)(#[0-9a-zA-Z;/?:@&=+$\\.\\-_!~*\'\(\)%]+)?';
# Make links:
#### Old:
# $all =~ s/(http\:([^\)\]\}\<\>\s\"\']+))/<a href=\"$1\">$1<\/a>/ig;
# Current:
# $all =~ s/($urlPattern)/<a href=\"$1\">$1<\/a>/ig;
my $done = "";
while ($all =~ m/\A((.|\n)*?)($urlPattern)(.*?)\n/)
	{
	my $pre = $1;
	my $url = $3;
	# $urlPattern has 5 parens:
	my $line = $7; # To end of line
	die if !defined($line);
	my $post = "\n" . $';
	my $newpre = $pre;
	if (0 && $debug)
		{
		my $t = $pre;
		$t =~ s/\A(.|\n)*\n//;
		$line = "" if !defined($line);
		warn "URL FOUND. pre: $t url:$url line:$line|\n";
		}
	# Check for Ralph's link text syntax.  Example:
	# <RalphS> -> http://lists.w3.org/Archives/Team/w3t-mit/2005Jan/0052.html Philippe's two minutes
	# would have already been escaped to:
	# &lt;RalphS&gt; -&gt; http://lists.w3.org/Archives/Team/w3t-mit/2005Jan/0052.html Philippe's two minutes
	if ($ralphLinks
		&& $newpre =~ s/\&gt\;\s*\-\&gt\;\s*\Z/&gt; /	# > -> 
		&& $line !~ m/$urlPattern/	# no URL
		&& $line !~ m/\&gt\;/		# no >
		&& $line !~ m/\&lt\;/		# no <
			)
		{
		my $text = &Trim($line);
		# Quoted string?  If so, use that as link text.
		# <RalphS> -> http://whatever "Skiing pictures", DanC 2005-01-07
		if ($text =~ m/\A\"([^\"]+)\"/ && &Trim($1))
			{
			$post = $' . $post;
			$text = $1;
			# warn "MATCH QUOTED link text: $text\n";
			}
		my $link = "<a href=\"$url\">$text</a>";
		# warn "MATCH RALPH text: $text\n";
		$done .= $newpre . $link;
		$all = $post;
		}
	else	{
		# Any other URL
		my $link = "<a href=\"$url\">$url</a>";
		$done .= $pre . $link;
		$all = $line . $post;
		}
	}
$done .= $all;
$all = $done;
return($all);
}


################################################################
#################### &Warn #############################
############################################################
# Write a warning and save it in a buffer so that it can be embedded into
# the minutes output later.
sub Warn
{
my $m = "" . join("", @_);
warn $m;
$diagnostics .= $m;
}

################################################################
#################### Die #############################
############################################################
# Output any diagnostics and die.
sub Die
{
&Warn(@_);
my $diagnosticsHTML = "<html><head><title>Scribe.perl: Fatal error</title></head>
<body><h1>Scribe.perl: Fatal error</h1>
<pre>
" . &EscapeHTML($diagnostics) . "
</pre>
</body>
</html>
";
print STDOUT $diagnosticsHTML;
close(STDOUT);
close(STDERR);
exit 1;
}

#################################################################
#################### EscapeHTML ################################
#################################################################
#  Escape < > as &lt; &gt; 
sub EscapeHTML
{
my $all = join("", @_);
# Escape & < and >:
$all =~ s/\&/\&amp\;/g;
$all =~ s/\</\&lt\;/g;
$all =~ s/\>/\&gt\;/g;
# $all =~ s/\"/\&quot\;/g;
return ($all);
}


#################################################################
#################### GetScribeNamesAndNicks #######################
#################################################################
# Determine @scribeNames and @scribeNicks and modify $all to change
# all <dbooth> lines to <scribe> lines, where dbooth is the scribeNick.
# The logic here is complicated by the fact that we have both a Scribe
# command and a ScribeNick command, and the given Scribe name will be
# treated as the ScribeNick (presumably if ScribeNick isn't specified).
# However, there is some ambiguity here.  In particular, if both a
# Scribe and later a ScribeNick is specified, then we don't know for
# sure whether that was supposed to be specifying two different scribes,
# or merely clarifying the IRC nickname of a single scribe.  We guess
# by looking ahead to see if we find any writer names <dbooth> matching
# the given Scribe name.
sub GetScribeNamesAndNicks
{
@_ == 3 || die;
my ($all, $scribeNamesRef, $scribeNicksRef) = @_;
my @scribeNames = @$scribeNamesRef;
my @scribeNicks = @$scribeNicksRef;
my @lines = grep {&Trim($_)} split(/\n/, $all); # Non-empty lines
my $totalLines = scalar(@lines);

# Look ahead to see how many Scribe and ScribeNick commands we have,
# and collect all the writer names (i.e., IRC nicknames).
# We do this to know whether we need to guess the scribeNick and
# to know whether there is only a single scribe that should thus
# take effect from the beginning.
my @scribeCommands = ();
my @scribeNickCommands = ();
my %writersFound = (); # Maps lower case nickname --> Mixed case
COUNT_SCRIBE_COMMANDS: for (my $i=0; $i<@lines; $i++)
	{
	die if !defined($lines[$i]);
	my ($writer, $type, $value, $rest, $allButWriter) = &ParseLine($lines[$i]);
	# Avoid unused var warning:
	($writer, $type, $value, $rest, $allButWriter) = 
		($writer, $type, $value, $rest, $allButWriter); 
	my $lcWriter = &LC($writer);
	$writersFound{$lcWriter} = $writer;
	# Scribe command?
	# $type is one of: COMMAND STATUS SPEAKER CONTINUATION PLAIN ""
	if ($type eq "COMMAND" && $value eq "scribe")
		{
		# Scribe command.  Changing scribe name.
		my $newScribeName = &EscapeHTML(&Trim($rest));
		push(@scribeCommands, $newScribeName);
		# warn "Found Scribe command: $newScribeName\n";
		}
	# ScribeNick command?
	# Should this be checking against "scribe_nick" instead, since that
	# would be the lower case of the preferred spelling?
	elsif ($type eq "COMMAND" && $value eq "scribenick")
		{
		my $newScribeNick = &EscapeHTML(&Trim($rest));
		push(@scribeNickCommands, $newScribeNick);
		# warn "Found ScribeNick command: $newScribeNick\n";
		}
	else {} # Do nothing
	}
@scribeCommands = &CaseInsensitiveUniq(@scribeCommands);
@scribeNickCommands = &CaseInsensitiveUniq(@scribeNickCommands);

# Infer the ScribeNick from ScribeName?
my @totalScribes = &CaseInsensitiveUniq(@scribeCommands, @scribeNames);
my @totalScribeNicks = &CaseInsensitiveUniq(@scribeNickCommands, @scribeNicks);
if ((!@totalScribeNicks) && (@totalScribes==1) && exists($writersFound{&LC($totalScribes[0])}))
	{
	my $scribeNick = $totalScribes[0];
	# &Warn("No ScribeNick specified.  Inferring ScribeNick: $scribeNick\n");
	push(@scribeNicks, $scribeNick);
	}

# Guess the ScribeNick if none was specified or inferrable.
@totalScribeNicks = &CaseInsensitiveUniq(@scribeNickCommands, @scribeNicks);
if (((!@totalScribeNicks) && (!@totalScribes))
  || ((!@totalScribeNicks) && (@totalScribes==1) && (!exists($writersFound{&LC($totalScribes[0])})) && !exists($writersFound{"scribe"})))
	{
	my $scribeNick = &GuessScribeNick($all);
	&Warn("No ScribeNick specified.  Guessing ScribeNick: $scribeNick\n");
	push(@scribeNicks, $scribeNick);
	}

# If there is only one Scribe command, let it take effect from the beginning:
@scribeNames = @scribeCommands if (!@scribeNames) && (@scribeCommands == 1);
# Ditto if there is only one ScribeNick command:
@scribeNicks = @scribeNickCommands if (!@scribeNicks) && (@scribeNickCommands == 1);

# Now we're ready to process potentially multiple scribes,
# which involves changing each "<dbooth> ..." line to "<scribe> ...",
# where dbooth is the current scribeNick.
my $currentScribeName = "";
$currentScribeName = $scribeNames[0] if @scribeNames==1;
my $currentScribeNick = "";
$currentScribeNick = $scribeNicks[0] if @scribeNicks==1;
my $currentScribeNickPattern = join("|", map {quotemeta $_} @scribeNicks);
$currentScribeNickPattern = join("|", map {quotemeta $_} @scribeNames) 
	if !$currentScribeNickPattern;
my $nLinesCurrentScribeNick = 0; # Lines matching current scribeNick
my $previousCommand = "";	# Previous command was Scribe or ScribeNick?
$previousCommand = "scribe" if @scribeNames && !@scribeNicks;
$previousCommand = "scribenick" if @scribeNicks && !@scribeNames;
LINE: for (my $i=0; $i<@lines; $i++)
	{
	die if !defined($lines[$i]);
	my ($writer, $type, $value, $rest, $allButWriter) = &ParseLine($lines[$i]);
	# Avoid unused var warning:
	($writer, $type, $value, $rest, $allButWriter) = 
		($writer, $type, $value, $rest, $allButWriter); 
	# warn "LINE: $lines[$i]\n" if $debug;
	# warn "currentScribeNickPattern: $currentScribeNickPattern\n" if $debug && $writer =~ m/dbooth/;
	# Is this any kind of scribe line?
	if ($currentScribeNickPattern && ($writer =~ m/\A$currentScribeNickPattern\Z/i))
		{ # Scribe line "<dbooth> ...".  Convert to "<scribe> ..."
		$lines[$i] = "<scribe> $allButWriter";
		$nLinesCurrentScribeNick++; # This may include <scribe> lines
		}
	# Scribe command?
	# $type is one of: COMMAND STATUS SPEAKER CONTINUATION PLAIN ""
	if ($type eq "COMMAND" && $value eq "scribe")
		{
		# Scribe command.  Changing scribe name.
		my $newScribeName = &EscapeHTML(&Trim($rest));
		push(@scribeNames, $newScribeName);
		&Warn("Found Scribe: $newScribeName\n");
		# Look ahead (until the next Scribe: or ScribeNick: command)
		# to see if the given name matches an IRC nick or <scribe>.  
		# If so, use it as the $currentScribeNick.
		my $lcNewScribeName = &LC($newScribeName);
		my $newNickFound = "";
		my $lastType = ""; 	# Last $type seen in lookahead loop
		my $lastValue = "";	# Last $value seen in lookahead loop
		LOOKAHEAD: for (my $j=$i+1; $j<@lines; $j++)
			{
			die if !defined($lines[$j]);
			my ($writer2, $type2, $value2, $rest2, $allButWriter2) = &ParseLine($lines[$j]);
			# Avoid unused var warning:
			($writer2, $type2, $value2, $rest2, $allButWriter2) =
				($writer2, $type2, $value2, $rest2, $allButWriter2);
			$lastType = $type2;
			$lastValue = $value2;
			my $lcWriter2 = &LC($writer2);
			if (($lcWriter2 eq $lcNewScribeName)
					|| ($lcWriter2 eq "scribe"))
				{
				$newNickFound = $writer2;
				# warn "newNickFound: $newNickFound LINE: $lines[$j]\n" if $debug;
				last LOOKAHEAD;
				}
			last LOOKAHEAD if ($type2 eq "COMMAND" && $value2 eq "scribe");
			last LOOKAHEAD if ($type2 eq "COMMAND" && $value2 eq "scribenick");
			}
		if ($newNickFound)
			{
			# Found either <$newScribeName> or <scribe>.
			# scribeNick should change.
			&Warn("Inferring ScribeNick: $newNickFound\n");
			if ($currentScribeNickPattern && $nLinesCurrentScribeNick == 0)
				{
				&Warn("WARNING: No scribe lines found matching previous ScribeNick pattern: <$currentScribeNickPattern> ...\n")
					if $newNickFound !~ m/\A$currentScribeNickPattern\Z/i;
				}
			push(@scribeNicks, $newNickFound);
			$currentScribeNick = $newNickFound;
			$currentScribeNickPattern = quotemeta($currentScribeNick);
			$nLinesCurrentScribeNick = 0;
			}
		else	{
			# Got a Scribe: command with no matching lines.
			# If there is a ScribeNick: command following, then
			# it's okay -- we'll use the given ScribeNick
			# when we get to it.  Otherwise, it's an error.
			if ($previousCommand ne "scribenick"
			  && @totalScribes>1 && @totalScribeNicks>1
			  && (!(($lastType eq "COMMAND") && ($lastValue eq "scribenick"))))
				{
				&Warn("\nWARNING: \"Scribe: $newScribeName\" command found, \nbut no lines found matching \"<$newScribeName> . . . \"\n");
				&Warn("Continuing with ScribeNick: <$currentScribeNickPattern>\n") if $currentScribeNickPattern;
				&Warn("Use \"ScribeNick: dbooth\" (for example) to specify the scribe's IRC nickname.\n\n")
				}
			# Hmm, should the above be checking for "scribe_nick"
			# (the canonical form) instead?
			}
		$previousCommand = "scribe";
		}
	# ScribeNick command?
	# Should this be checking against "scribe_nick" instead, since that
	# would be the lower case of the preferred spelling?
	elsif ($type eq "COMMAND" && $value eq "scribenick")
		{
		my $newScribeNick = &EscapeHTML(&Trim($rest));
		push(@scribeNicks, $newScribeNick);
		if ($currentScribeNickPattern && $nLinesCurrentScribeNick == 0
			&& $newScribeNick !~ m/\A$currentScribeNickPattern\Z/i)
			{
			&Warn("WARNING: No scribe lines found matching ScribeNick pattern: <$currentScribeNickPattern> ...\n");
			}
		&Warn("Found ScribeNick: $newScribeNick\n");
		$currentScribeNick = $newScribeNick;
		$currentScribeNickPattern = quotemeta($newScribeNick);
		$nLinesCurrentScribeNick = 0;
		$previousCommand = "scribenick";
		}
	else {} # Do nothing
	}
if ($currentScribeNickPattern && $nLinesCurrentScribeNick == 0)
	{
	&Warn("WARNING: No scribe lines found matching ScribeNick pattern: <$currentScribeNickPattern> ...\n");
	}
$all = "\n" . join("\n", @lines) . "\n";
@scribeNames = &CaseInsensitiveUniq(@scribeNames);
@scribeNicks = &CaseInsensitiveUniq(@scribeNicks);

# Default to using ScribeNicks for ScribeNames if no ScribeNames.
if ((!@scribeNames) && @scribeNicks)
	{
	@scribeNames = @scribeNicks;
	my $scribeNames = join(", ", @scribeNames);
	&Warn("Inferring Scribes: $scribeNames\n");
	}
# No Scribes or ScribeNicks specified?
&Warn("WARNING: No Scribe or ScribeNick could be determined.\nYou can specify the Scribe or ScribeNick like:\n  <dbooth> Scribe: Michael Sperberg-McQueen\n  <dbooth> ScribeNick: msm\n\n")
	if ((!@scribeNames) && !@scribeNicks);
# Check for possible scribeNick name error by counting the number
# of <scribe> lines.
# Also ensure consistency (lower case) in the spelling of <scribe>.
# WARNING: Pattern match (annoyingly) returns "" if no match -- not 0.
my $totalScribeLines = ($all =~ s/\n\<scribe\>/\n\<scribe\>/ig);
$totalScribeLines = 0 if !$totalScribeLines;
&Warn("\nWARNING: $totalScribeLines scribe lines found (out of $totalLines total lines.)\nAre you sure you specified a correct ScribeNick?\n\n")
	if (($totalLines > 100) && ($totalScribeLines/$totalLines < 0.01))
		|| ($totalScribeLines < 5);

# warn "GetScribeNamesAndNicks RETURNING ScribeNames: @scribeNames ScribeNicks: @scribeNicks\n" if $debug;
return ($all, \@scribeNames, \@scribeNicks);
}

######################################################################
######################## ConvertDashTopics ###########################
######################################################################
# Treat dash lines as starting a new topic:
#	<Philippe> ---
#	<Philippe> UTF16 PR issue
# as equivalent to:
#	<Philippe> Topic: UTF16 PR issue
sub ConvertDashTopics
{
@_ == 1 || die;
my ($all) = @_;
my $nFound = 0;
my @lines = split(/\n/, $all);
for(my $i=0; $i<@lines-1; $i++)
	{
	die if !defined($lines[$i]);
	my ($writer, $type, undef, $rest, undef) = &ParseLine($lines[$i]);
	# Dash separator line?  <Philippe> ---
	next if ($type ne "PLAIN" || $rest !~ m/\A\-+\Z/);
	# Some other writer may have said something
	# between the dash separator line and the topic line, 
	# so look forward for the next line by the same writer.
	INNER: for (my $j=$i+1; $j<@lines; $j++)
		{
		my ($writer2, $type2, $value2, undef, $allButWriter2) = &ParseLine($lines[$j]);
		# Same writer?
		next if $writer2 ne $writer;
		# Empty lines don't count.
		next if $type2 eq "";
		next if $allButWriter2 eq "";
		# warn "writer2: $writer2 type2: $type2 value2: $value2 allButWriter2: $allButWriter2 lines[j]: $lines[$j]\n";
		# Do nothing if the next scribe line is a Topic: command anyway
		last INNER if ($type2 eq "COMMAND" && $value2 eq "topic");
		# Turn: 
		#	<Philippe> UTF16 PR issue
		# into: 
		#	<Philippe> Topic: UTF16 PR issue
		$lines[$j] = "\<$writer\> Topic: $allButWriter2";
		$nFound++;
		# $type2 is one of: COMMAND STATUS SPEAKER CONTINUATION PLAIN ""
		if ($type2 eq "COMMAND" || $type2 eq "STATUS" 
			|| ($type2 eq "CONTINUATION" && $value2 !~ m/\A\s*\Z/))
			{
			&Warn("\nWARNING: Unusual topic line found after \"$rest\" topic separator:" . $lines[$j] . "\n\n") if $dashTopics;
			# warn "value2: $value2\n";
			}
		last INNER;
		}
	}
$all = "\n" . join("\n", @lines) . "\n";
return($all, $nFound);
}

###############################################################
################# WordVariationsMap ###########################
###############################################################
# Generates word variations and returns a map from each lower case
# variation to the preferred (original) mixed case form.
sub WordVariationsMap
{
my @words = @_;	# Preferred mixed case words.
my %map = ();	# Maps each lower case variation to preferred mixed case form.
foreach my $w (@words)
	{
	die if (!defined($w)) || $w eq "";
	my @variations = &WordVariations(&LC($w));
	foreach my $v (@variations)
		{
		$map{$v} = $w;
		}
	}
return(%map);
}

###################################################################
####################### WordVariations #######################
###################################################################
# Generate spelling variations of the given words, e.g.
#	Previous_Minutes
#	Previous-Minutes
#	Previous Minutes
#	PreviousMinutes
sub WordVariations
{
my @old = @_;
my @new = map { 
		my @w=($_); 
		# Allow variations of multiword words:
		push(@w, $_) if ($_ =~ s/[_\-\ ]+/\_/g); # Previous_Minutes
		push(@w, $_) if ($_ =~ s/[_\-\ ]+/\-/g); # Previous-Minutes
		push(@w, $_) if ($_ =~ s/[_\-\ ]+/\ /g); # Previous Minutes
		push(@w, $_) if ($_ =~ s/[_\-\ ]+//g);   # PreviousMinutes
		# warn "VARIATIONS: @w\n";
		&Uniq(@w);
		} @old;
return(@new);
}

###################################################################
####################### Equal #######################
###################################################################
# Compare two lists for equality.
# Items are compared as strings.
# Lists must be given as references: if (&Equal(\@a, \@b)) { ... }
sub Equal
{
@_ == 2 || die;
my ($aRef, $bRef) = @_;
my @a = @{$aRef};
my @b = @{$bRef};
return undef if scalar(@a) != scalar(@b);  # Unequal lengths?
for (my $i=0; $i<@a; $i++)
	{
	return undef if $a[$i] ne $b[$i];
	}
return 1;
}

###################################################################
####################### CaseInsensitiveUniq #######################
###################################################################
# Return one copy of each thing in the given list.
# Order is preserved, case is ignored.
sub CaseInsensitiveUniq
{
my @words = @_;
my %seen = (); # LC version
my @result = ();
foreach my $w (@words)
	{
	my $lcw = &LC($w);	# Lower case
	next if exists($seen{$lcw});
	$seen{$lcw} = $w;
	push(@result, $w);
	}
return(@result);
}

###################################################################
####################### Uniq #######################
###################################################################
# Return one copy of each thing in the given list.
# Order is preserved.
sub Uniq
{
my @words = @_;
my %seen = ();
my @result = ();
foreach my $w (@words)
	{
	next if exists($seen{$w});
	$seen{$w} = $w;
	push(@result, $w);
	}
return(@result);
}

###################################################################
####################### MakePattern2 #######################
###################################################################
# Generate a pattern matching any of the given words, e.g.:
#	dog|cat|pig
# Compound words may be given, such as "Big Dog", "Big-Dog" or "Big_Dog",
# in which case they are converted to patterns that match any form:
#	Big[ _\-]?Dog
# which will match any of:
#	"BigDog", "Big_Dog", "Big-Dog" or "Big Dog"
# No parentheses are used, so you should put parens around the
# resulting pattern.
sub MakePattern2
{
# ***  This is a new, untested version.  It should make WordVariations obsolete.
@_ > 0 || die;
my @words = grep {die if (!defined($_)) || $_ eq ""; $_} @_;
@words = map {s/[ _\-]/_/g; $_} @words; # Big-Dog --> Big_Dog
@words = map {quotemeta($_)} @words;
@words = map {s/_/\[ _\\\-\]\?/g; $_} @words; # Big_Dog --> Big[ _\-]?Dog
my $pattern =  join("|", @words);
return $pattern;
}

###################################################################
####################### MakePattern #######################
###################################################################
# Generate a pattern matching any of the given words, e.g.:
#	dog|cat|pig
# No parentheses are used, so you should put parens around the
# resulting pattern.
sub MakePattern
{
@_ > 0 || die;
my @words = grep {die if (!defined($_)) || $_ eq ""; $_} @_;
my $pattern =  join("|", map {quotemeta($_)} @words);
return $pattern;
}

###################################################################
####################### ParseLine #######################
###################################################################
# Parse the line and return:
#	$writer		E.g. dbooth from "<dbooth> ..."
#	$type		One of: COMMAND STATUS SPEAKER CONTINUATION PLAIN
#	$value		Either: the command; the speaker; the continuation
#			pattern; the status; or empty (if $type is PLAIN).
#			If $type is COMMAND, then $value is guaranteed
#			lower case.  If $type is STATUS, then $value is
#			guaranteed upper case.  Otherwise, it may be mixed case.
#	$rest		The rest of the line (no $writer or $value), &Trim()'ed
#	$allButWriter	All but the <writer> part, &Trim()'ed.
sub ParseLine
{
@_ == 1 || die;
my ($line) = @_;
die if !defined($line);
my ($writer, $type, $value, $rest, $allButWriter) = ("", "", "", "", "");
# Remove "<dbooth> " from the $line
if ($line =~ s/\A(\s?)\<([\w\_\-\.]+)\>(\s?)//)
	{
	$writer = $2;
	}
# "<dbooth> " has now been removed from the $line
$allButWriter = &Trim($line);
# Action status?
# This matches a line beginning with a status word.
if ($line =~ m/\A\W*\b($actionStatusesPattern)\b\W*/i)
	{
	$type = "STATUS";
	$value = $1;
	$rest = $';
	# die "LINETYPE a s type: $type value: $value rest: $rest\n";
	# Don't map to preferred spelling, but make it upper case.
	# Old: $value = $actionStatuses{&LC($value)}; # Map to pref spelling
	$value =~ tr/a-z/A-Z/; # Make upper case but not pref spelling
	}
# Command?
# This pattern allows up to two *extra* leading spaces for commands
elsif ($line =~ m/\A(\s?(\s?))($commandsPattern)(\s?)\:\s*/i)
	{
	$type = "COMMAND";
	$value = $3;
	$rest = $';
	$value = &LC($value);
	# Put command in lower case canonical form (no spaces or underscore):
	if (!exists($commands{$value}))
		{
		#### I have no idea why this next line is here.  An internal guard?
		&Warn("ERROR: ParseLine value: $value line: $line\n") if $line =~ m/topic/i;
		#### I assume the following error is what is needed here.
		&Die("INTERNAL ERROR: Unknown command: $line\n");
		}
	# $value = $commands{&LC($value)}; # previous_meeting --> Previous_Meeting
	$value = &LC($commands{$value}); # PreviousMeeting --> previous_meeting
	}
# Speaker statement?
# This pattern allows up to two *extra* leading spaces for speaker statements
elsif ($line =~ m/\A(\s?)(\s?)([_\w\-\.]+)(\s?)\:\s*/)
	{
	$value = $3;
	$rest = $';
	# Make sure it's not in the stopList (non-name).
	if (!exists($stopList{&LC($value)}))
		{
		# Must be a speaker statement.
		$type = "SPEAKER";
		}
	}
# Continuation line?
# if ((!$type) && $line =~ m/\A((\s)|(\s?(\s?)\.\.+(\s?)(\s?)))/)
if (((!$type) && $line =~ m/\A(\s?(\s?)\.\.+(\s?)(\s?))/)
	|| ($allowSpaceContinuation && (!$type) && $line =~ m/\A(\s)/))
	{
	$type = "CONTINUATION";
	# $value = $&;
	$rest = $';
	$value = $preferredContinuation; # Standardize
	}
if (!$type)
	{
	# Must be plain line
	$value = "";
	$rest = $line;
	$type = "PLAIN";
	}
$rest = &Trim($rest);
return ($writer, $type, $value, $rest, $allButWriter);
}

###################################################################
####################### ParseChunk ################################
###################################################################
# Use ParseLine to parse the next chunk of input, which involves
# skipping over blank lines and joining continuation lines.
# Returns:
#	$writer		E.g. dbooth from "<dbooth> ..."
#	$type		One of: COMMAND STATUS SPEAKER CONTINUATION PLAIN ""
# 			(I.e., $type is "" if no writer.)
#	$value		Either: the command; the speaker; the continuation
#			pattern; the status; or empty (if $type is PLAIN).
#			If $type is COMMAND, then $value is guaranteed
#			lower case.  If $type is STATUS, then $value is
#			guaranteed upper case.  Otherwise, it may be mixed case.
#	$rest		The rest of the line (no $writer or $value), &Trim()'ed
#	$allButWriter	All but the <writer> part, &Trim()'ed.
sub ParseChunk
{
die; ########## UNFINISHED 
@_ == 1 || die;
my ($all) = @_;
die if !defined($all);
my ($writer, $type, $value, $rest, $allButWriter) = ("", "", "", "", "");
while (1)
	{
	last if ($all !~ s/\A.*\n//);
	my $line = $&;
	chomp($line);
	# **** stopped here **** 
	($writer, $type, $value, $rest, $allButWriter) = &ParseLine($line);
	next if $allButWriter eq "";
	}
return ("", "", "", "", ""); # EOF
}

###################################################################
####################### CaseInsensitiveSort #######################
###################################################################
sub CaseInsensitiveSort
{
return( sort {&LC($a) cmp &LC($b)} @_ );
}

###################################################################
####################### GetPresentFromZakim ##########################
###################################################################
# Get the list of people present, as reported by zakim bot:
#	<Zakim> Attendees were Dbooth, Dietmar_Gaertner, Plh, GlenD,
#	<Zakim> ... IgorS, J.Mischkinsky, Lily, Umit, sanjiva, bijan,
sub GetPresentFromZakim
{
@_ == 1 || die;
my ($all) = @_;
die if !defined($all);
my @present = ();			# People present at the meeting
my @zakimLines = grep {s/\A\<Zakim\>\s*//i;} split(/\n/, $all);
my $t = join("\n", grep {s/\A\<Zakim\>\s*//i;} split(/\n/, $all)); 
# Join zakim continuation lines
$t =~ s/\n\.\.\.\.*\s*/ /g;
# die "t:\n$t\n" . ('=' x 70) . "\n\n";
@zakimLines = split(/\n/, $t);
foreach my $line (@zakimLines)
	{
	if ($line =~ m/Attendees\s+((were)|(have\s+been))\s+/i)
		{
		my $raw = $';
		my @people = map {$_ = &EscapeHTML(&Trim($_)); s/\s+/_/g; $_} split(/\,/, $raw);
		next if !@people;
		if (@present)
			{
			# Skip warning if new list is a superset of old.
			my @tOldPlusNew = &Uniq(sort (@present, @people));
			my @tNew = &Uniq(sort @people);

			&Warn("\nWARNING: Replacing list of attendees.\nOld list: @present\nNew list: @people\n\n")
				if (!&Equal(\@tOldPlusNew, \@tNew));
			}
		@present = @people;
		}
	}
return(@present);
}

###################################################################
####################### GetPresentOrRegrets ##########################
###################################################################
# Look for explicit "Present: ..." or "Regrets: ..." commands.
# Arguments: $keyword, $minPeople, $all, @present (default)
# Returns: ($all, @present)
# $all is modified by removing any "Present: ..." commands.
sub GetPresentOrRegrets
{
@_ >= 3 || die;
my (	$keyword, 	# What we're looking for: "Present" or "Regrets"
	$minPeople, 	# Min number of people to avoid a warning
	$all, 		# The input
	@present	# Default people present at the meeting
	) = @_;
die if !defined($all);
my @allLines = split(/\n/, $all);
# <dbooth> Present: Amy Frank Joe Carol
# <dbooth> Present: David Booth, Frank G, Joe Camel, Carole King
# <dbooth> Present+: Justin
# <dbooth> Present+ Silas
# <dbooth> Present-: Amy
my @possiblyPresent = @uniqNames;	# People present at the meeting
my @newAllLines = ();	# Collect remaining lines
# push(@allLines, "<dbooth> Present: David Booth, Frank G, Joe Camel, Carole King"); # test
# push(@allLines, "<dbooth> Present: Amy Frank Joe Carole"); # test
# push(@allLines, "<dbooth> Present+: Justin"); # test
# push(@allLines, "<dbooth> Present+ Silas"); # test
# push(@allLines, "<dbooth> Present-: Amy"); # test
my $isAlreadyDefined = 0;
foreach my $line (@allLines)
	{
	$line =~ s/\s+\Z//; # Remove trailing spaces.
	if ($line !~ m/\A\<[^\>]+\>\s*$keyword\s*(\:|((\+|\-)\s*\:?))\s*(.*)\Z/i)
		{
		push(@newAllLines, $line);
		next;
		}
	my $plus = $1;
	my $present = &EscapeHTML($4);
	my @p = ();
	if ($present =~ m/\,/)
		{
		# Comma-separated list
		@p = grep {$_ && $_ ne "and"} 
				map {$_ = &Trim($_); s/\s+/_/g; $_} 
				split(/\,/,$present);
		}
	else	{
		# Space-separated list
		@p = grep {$_} split(/\s+/,$present);
		}
	if ($plus =~ m/\+/)
		{
		my %seen = map {($_,$_)} @present;
		my @newp = grep {!exists($seen{$_})} @p;
		push(@present, @newp);
		}
	elsif ($plus =~ m/\-/)
		{
		my %seen = map {($_,$_)} @present;
		foreach my $p (@p)
			{
			delete $seen{$p} if exists($seen{$p});
			}
		@present = sort keys %seen;
		}
	else	{
		# Skip warning if new list is superset of old list
		my @tOldPlusNew = &Uniq(sort (@present, @p));
		my @tNew = &Uniq(sort @p);
		if (!&Equal(\@tOldPlusNew, \@tNew))
			{
			&Warn("\nWARNING: Replacing previous $keyword list. (Old list: " . join(", ",@present) . ")\nUse '$keyword\+ ... ' if you meant to add people without replacing the list,\nsuch as: <dbooth> $keyword\+ " . join(', ', @p) . "\n\n") if @present && $isAlreadyDefined;
			}
		@present = @p;
		$isAlreadyDefined = 1;
		}
	}
@allLines = @newAllLines;
$all = "\n" . join("\n", @allLines) . "\n";
if (@present == 0)	
	{
	if ($keyword ne "Regrets" || $warnIfNoRegrets)
		{
		&Warn("\nWARNING: No \"$keyword\: ... \" found!\n");
		&Warn("Possibly Present: @possiblyPresent\n") if $keyword eq "Present"; 
		&Warn("You can indicate people for the $keyword list like this:
	<dbooth> $keyword\: dbooth jonathan mary
	<dbooth> $keyword\+ amy\n\n");
		}
	}
else	{
	&Warn("$keyword\: @present\n"); 
	&Warn("\nWARNING: Fewer than $minPeople people found for $keyword list!\n\n") if @present < $minPeople;
	}
return ($all, @present);
}

#######################################################################
################## PutSpeakerOnEveryLine ######################
#######################################################################
# Canonicalize Scribe continuation lines so that the speaker's name is 
# on every line.  Convert:
#	<dbooth> Scribe: dbooth
#	<dbooth> SusanW: We had a mtg on July 16.
#	<DanC_> pointer to minutes?
#	<dbooth> SusanW: I'm looking.
#	<dbooth> ... The minutes are on
#	<dbooth>  the admin timeline page.
# to:
#	<dbooth> Scribe: dbooth
#	<dbooth> SusanW: We had a mtg on July 16.
#	<DanC_> pointer to minutes?
#	<dbooth> SusanW: I'm looking.
#	<dbooth> SusanW: The minutes are on
#	<dbooth> SusanW: the admin timeline page.
# Unfortunately, I don't remember why I did this.  I assume it was to
# make subsequent processing easier, but now I don't know why it is needed.
sub PutSpeakerOnEveryLine
{
@_ == 1 || die;
my ($all) = @_;
my @allLines = split(/\n/, $all);
my $currentSpeaker = "UNKNOWN_SPEAKER";
for (my $i=0; $i<@allLines; $i++)
	{
	# warn "$allLines[$i]\n" if $allLines[$i] =~ m/Liam/; # debug
	if ($allLines[$i] =~ m/\A\<scribe\>(\s?\s?)($speakerPattern)\s*\:/i)
		{
		my $cs = $2;
		my $lccs = &LC($cs);
		$currentSpeaker = $cs if !exists($stopList{$lccs});
		}
	# Dot continuation line: "<dbooth> ... The minutes are on".
	# I'm not sure the following is right.  If there is a continuation
	# line after a non-speaker line, such as "Topic: whatever", then
	# I think this will act as a continuation of the previous speaker
	# line, which may not be the right thing to do.
	# (Rather, it probably should be a continuation line of the topic.)
	# I think the code for this program should be restructured, to
	# act globally on one line at a time, with look-ahead used to
	# join continuation lines on to the current line.
	# The following commented out version is for when the code is changed
	# to not remove (and later replace) the "...":
	# elsif ($allLines[$i] =~ s/\A\<scribe\>(\s?)\.\./\<scribe\> $currentSpeaker: ../i)
	elsif ($allLines[$i] =~ s/\A\<scribe\>(\s?)\.\.+(\s?)/\<scribe\> $currentSpeaker: /i)
		{
		# warn "Scribe NORMALIZED: $& --> $allLines[$i]\n";
		&Warn("\nWARNING: UNKNOWN SPEAKER: $allLines[$i]\nPossibly need to add line: <Zakim> +someone\n\n") if $currentSpeaker eq "UNKNOWN_SPEAKER";
		}
	# Leading-blank continuation line: "<dbooth>  the admin timeline page.".
	elsif ($allLines[$i] =~ s/\A\<scribe\>\s\s/\<scribe\> $currentSpeaker:  /i)
		{
		# warn "Scribe NORMALIZED: $& --> $allLines[$i]\n";
		&Warn("\nWARNING: UNKNOWN SPEAKER: $allLines[$i]\nPossibly need to add line: <Zakim> +someone\n\n") if $currentSpeaker eq "UNKNOWN_SPEAKER";
		}
	else	{
		}
	}
$all = "\n" . join("\n", @allLines) . "\n";
# die "all:\n$all\n" . ('=' x 70) . "\n\n";
return $all;
}


#################################################################
################# GuessScribeNick #################
#################################################################
# Guess the scribe IRC nickname based on who wrote the most in the log.
sub GuessScribeNick
{
@_ == 1 || die;
my ($all) = @_;
$all = &IgnoreGarbage($all);
my @lines = split(/\n/, $all);
my $nLines = 0;	# Total number of "<someone> something " lines.
my %nameCounts = (); # Count of the number of lines written per person.
my %mixedCaseNames = (); # Map from lower case name to mixed case name
foreach my $line (@lines)
	{
	if ($line =~ m/\A\<([^\>]+)\>/)
		{
		$nLines++;
		my $mix = $1;	# Liam
		my $who = &LC($mix);	# liam
		$nameCounts{$who}++;
		$mixedCaseNames{$who} = $mix; # liam -> Liam
		}
	}
my @descending = sort { $nameCounts{$b} <=> $nameCounts{$a} } keys %nameCounts;
# warn "Names in descending order:\n";
foreach my $n (@descending)
	{
	# warn "	$nameCounts{$n} $n\n";
	}
# warn "\n";
return "" if !@descending; # None
return $mixedCaseNames{$descending[0]};
}


#################################################################
################# IgnoreGarbage #################
#################################################################
# Ignore off-record lines and other lines that should not be minuted.
sub IgnoreGarbage
{
@_ == 1 || die;
my ($all) = @_;
my @lines = split(/\n/, $all);
my $nLines = scalar(@lines);
# warn "Lines found: $nLines\n";
my @scribeLines = ();
foreach my $line (@lines)
	{
	next if &IsIgnorable($line);
	# warn "KEPT: $line\n";
	push(@scribeLines, $line);
	}
my $nScribeLines = scalar(@scribeLines);
# &Warn("Minuted lines found: $nScribeLines\n");
$all = "\n" . join("\n", @scribeLines) . "\n";

# Verify that we axed all join/leave lines:
my @matches = ($all =~ m/.*has joined.*\n/g);
&Warn("\nWARNING: Possible internal error: join/leave lines remaining: \n\t" . join("\t", @matches) . "\n\n")
 	if @matches;
return $all;
}

#################################################################
#################### IsBotLine ###############################
#################################################################
# Given a single line, returns 1 if it is an IRC, Zakim or RRSAgent command
# or response.
sub IsBotLine
{
@_ == 1 || die;
my ($line) = @_;
die if $line =~ m/\n/; # Should be given only one line (with no \n).
# Join/leave lines:
return 1 if $line =~ m/\A\s*\<($namePattern)\>\s*\1\s+has\s+(joined|left|departed|quit)\s*((\S+)?)\s*\Z/i;
return 1 if $line =~ m/\A\s*\<(scribe)\>\s*$namePattern\s+has\s+(joined|left|departed|quit)\s*((\S+)?)\s*\Z/i;
# Topic change lines:
# <geoff_a> geoff_a has changed the topic to: Trout Mask Replica
return 1 if $line =~ m/\A\s*\<($namePattern)\>\s*\1\s+(has\s+changed\s+the\s+topic\s+to\s*\:.*)\Z/i;
return 1 if $line =~ m/\A\s*\<scribe\>\s*($namePattern)\s+(has\s+changed\s+the\s+topic\s+to\s*\:.*)\Z/i;
# Zakim lines
return 1 if $line =~ m/\A\<Zakim\>/i;
return 1 if $line =~ m/\A\<$namePattern\>\s*zakim\s*\,/i;
return 1 if $line =~ m/\A\<$namePattern\>\s*agenda\s*\d*\s*[\+\-\=\?]/i;
return 1 if $line =~ m/\A\<$namePattern\>\s*close\s+agend(a|(um))\s+\d+\Z/i;
return 1 if $line =~ m/\A\<$namePattern\>\s*open\s+agend(a|(um))\s+\d+\Z/i;
return 1 if $line =~ m/\A\<$namePattern\>\s*take\s+up\s+agend(a|(um))\s+\d+\Z/i;
return 1 if $line =~ m/\A\<$namePattern\>\s*q\s*[\+\-\=\?]/i;
return 1 if $line =~ m/\A\<$namePattern\>\s*queue\s*[\+\-\=\?]/i;
return 1 if $line =~ m/\A\<$namePattern\>\s*ack\s+$namePattern\s*\Z/i;
# RRSAgent lines
return 1 if $line =~ m/\A\<RRSAgent\>/i;
return 1 if $line =~ m/\A\<$namePattern\>\s*RRSAgent\s*\,/i;
# If we get here, it isn't a bot line.
# warn "KEPT: $line\n";
return 0;
}

#################################################################
#################### IsIgnorableOtherBotLine ###############################
#################################################################
# Given a single line, returns 1 if it is some other bot command or line
# that should be ignored.
sub IsIgnorableOtherBotLine
{
@_ == 1 || die;
my ($line) = @_;
die if $line =~ m/\n/; # Should be given only one line (with no \n).
# Join/leave lines:
return 1 if $line =~ m/\A\s*\<($namePattern)\>\s*\1\s+has\s+(joined|left|departed|quit)\s*((\S+)?)\s*\Z/i;
return 1 if $line =~ m/\A\s*\<(scribe)\>\s*$namePattern\s+has\s+(joined|left|departed|quit)\s*((\S+)?)\s*\Z/i;
# Topic change lines:
# <geoff_a> geoff_a has changed the topic to: Trout Mask Replica
return 1 if $line =~ m/\A\s*\<($namePattern)\>\s*\1\s+(has\s+changed\s+the\s+topic\s+to\s*\:.*)\Z/i;
return 1 if $line =~ m/\A\s*\<scribe\>\s*($namePattern)\s+(has\s+changed\s+the\s+topic\s+to\s*\:.*)\Z/i;
# If we get here, it isn't a bot line.
# warn "KEPT: $line\n";
return 0;
}

#################################################################
#################### IsIgnorableRRSAgentLine ###############################
#################################################################
# Given a single line, returns 1 if it is a RRSAgent command
# or response that should be ignored.
sub IsIgnorableRRSAgentLine
{
@_ == 1 || die;
my ($line) = @_;
die if $line =~ m/\n/; # Should be given only one line (with no \n).
# RRSAgent lines
return 1 if $line =~ m/\A\<RRSAgent\>/i;
return 1 if $line =~ m/\A\<$namePattern\>\s*RRSAgent\s*\,/i;
# If we get here, it isn't a bot line.
# warn "KEPT: $line\n";
return 0;
}

#################################################################
#################### IsIgnorableZakimLine ###############################
#################################################################
# Given a single line, returns 1 if it is a Zakim command
# or response that should be ignored (i.e., not included in the
# generated minutes).
sub IsIgnorableZakimLine
{
@_ == 1 || die;
my ($line) = @_;
die if $line =~ m/\n/; # Should be given only one line (with no \n).
# Zakim lines to specifically keep
# <Zakim> chaalsNCE, you wanted to say AC members should have priority 
return 0 if $line =~ m/\A\<Zakim\>\s*\S+\, you wanted to /i;
# Zakim lines to ignore
return 1 if $line =~ m/\A\<Zakim\>/i;
return 1 if $line =~ m/\A\<$namePattern\>\s*zakim\s*\,/i;
return 1 if $line =~ m/\A\<$namePattern\>\s*ag(g?)enda\s*\d*\s*[\+\-\=\?]/i;
return 1 if $line =~ m/\A\<$namePattern\>\s*next\s+ag(g?)end(a|(um))\s*\Z/i;
return 1 if $line =~ m/\A\<$namePattern\>\s*close\s+ag(g?)end(a|(um))\s+\d+\Z/i;
return 1 if $line =~ m/\A\<$namePattern\>\s*open\s+ag(g?)end(a|(um))\s+\d+\Z/i;
return 1 if $line =~ m/\A\<$namePattern\>\s*take\s+up\s+ag(g?)end(a|(um))\s+\d+\Z/i;
return 1 if $line =~ m/\A\<$namePattern\>\s*q\s*[\+\-\=\?]/i;
return 1 if $line =~ m/\A\<$namePattern\>\s*queue\s*[\+\-\=\?]/i;
return 1 if $line =~ m/\A\<$namePattern\>\s*ack\s+$namePattern\s*\Z/i;
# If we get here, it isn't a Zakim line or Zakim command.
# warn "KEPT: $line\n";
return 0;
}

#################################################################
#################### IsIgnorable ################################
#################################################################
# Should the given line be ignored?
sub IsIgnorable
{
@_ == 1 || die;
my ($line) = @_;
die if $line =~ m/\n/; # Should be given only one line (with no \n).
# Ignore empty lines.
return 1 if &Trim($line) eq "";
# Ignore /me lines.  Up to 3 leading spaces before "*". (No <speaker>)
return 1 if $line =~ m/\A(\s?)(\s?)(\s?)\*/;
# Select only <speaker> lines
return 1 if $line !~ m/\A\<$namePattern\>/i;
# Ignore empty lines
return 1 if $line =~ m/\A\<$namePattern\>\s*\Z/i;
# Ignore bot lines
return 1 if &IsIgnorableZakimLine($line);
return 1 if &IsIgnorableRRSAgentLine($line);
return 1 if &IsIgnorableOtherBotLine($line);
# Remove off the record comments:
return 1 if $line =~ m/\A\<$namePattern\>\s*\[\s*off\s*\]/i;
# Select only <scribe> lines?
return 1 if $scribeOnly && $line !~ m/\A\<scribe\>/i;
# If we get here, we're keeping the line.
# warn "KEPT: $line\n";
return 0;
}

#################################################################
########################## WrapLine ###########################
#################################################################
# Try to break lines longer than $maxLineLength chars.
# Continuation lines are indented by $preferredContinuation.
# Input line should end with a newline;
# resulting lines will end with newlines.
# Lines are only broken at spaces.  Long words are never broken.
# Hence, the resulting line length may exceed the given $maxLineLength
# if there is a word that is longer than $maxLineLength (such as
# a URL).
sub WrapLine
{
@_ == 1 || @_ == 2 || die;
my ($line, $maxLineLength) = @_;
$maxLineLength = 67 if !defined($maxLineLength);
die if $line !~ m/\n\Z/;
my @result = ();
my $newLine = "";
my $nextWord = "";
while (1)
	{
	$newLine .= $nextWord;		# Append to $newLine
	last if ($line !~ s/\A\s*\S+//);	# Grab next word
	$nextWord = $&;
	if (length($newLine) > 0
	  && length($newLine) + length($nextWord) > $maxLineLength)
		{
		$newLine .= "\n";
		push(@result, $newLine);
		$newLine = $preferredContinuation;
		}
	}
$newLine .= "\n";
push(@result, $newLine);
return(@result);
}


##################################################################
########################## Mirc_Text_Format #########################
##################################################################
# Format from saving MIRC buffer.
sub Mirc_Text_Format
{
die if @_ != 1;
my ($all) = @_;
# Join continued lines:
$all =~ s/\n\ \ //g;
# Count the number of recognized lines
my @lines = split(/\n/, $all);
my $nLines = scalar(@lines);
my $n = 0;
# my $namePattern = '([\\w\\-]([\\w\\d\\-]*))';
# First line may be empty
if (@lines && &Trim($lines[0]) eq "")
	{
	$n++;
	shift @lines;
	}
# Second line may be:
#	Start of &t-and-s buffer: Fri Apr 16 21:44:19 2004
if (@lines && $lines[0] =~ m/\AStart of \S+ buffer/)
	{
	$n++;
	shift @lines;
	}
# Last line may be:
#	End of &t-and-s buffer    Fri Apr 16 21:44:19 2004
if (@lines && $lines[@lines-1] =~ m/\AEnd of \S+ buffer/i)
	{
	$n++;
	pop @lines;
	}
# Count remaining lines that look reasonable
my @loggedLines = ();
foreach my $line (@lines)
	{
	# * unlogged comment (delete)
	if ($line =~ m/\A(\s?)(\s?)(\s?)\*/) { $n++; $line = ""; }
	# <ericn> Discussion on how to progress
	elsif ($line =~ m/\A\<$namePattern\>\s/i) { $n++; }
	else	{
		# warn "MIRC not match: $line\n";
		}
	# warn "LINE: $line\n";
	push(@loggedLines, $line) if $line =~ m/\S/;
	}
my $score = $n / $nLines;
# warn "Mirc_Text_Format n: $n nLines: $nLines score: $score\n";
$all = join("\n", @loggedLines) . "\n";
# Artificially downgrade the score, so that Normalized_Format will win
# if the format is already normalized
$score = $score * 0.99;
return($score, $all);
}

##################################################################
########################## XChat_Timestamped_Log_Format #########################
##################################################################
# Format from saving MIRC buffer.
sub XChat_Timestamped_Log_Format
{
die if @_ != 1;
my ($all) = @_;
# Count the number of recognized lines
my @lines = split(/\n/, $all);
my $nLines = scalar(@lines);	# Total number of lines
my $n = 0;		# Number of recognized lines (matching this format)
# my $namePattern = '([\\w\\-]([\\w\\d\\-]*))';
# Count lines that look reasonable
# **** BEGIN LOGGING AT Mon Feb 14 08:37:02 2005
# Feb 14 08:37:02 -->     You are now talking on &arch
# Feb 14 08:37:02 ---     Topic for &arch is W3C Architecture Mardi Gras Meeting
# **** ENDING LOGGING AT Mon Feb 14 10:22:09 2005
# Feb 14 11:02:23 <dbooth>        This is an on-the-record comment
# Feb 14 11:02:26 *       Yves This is an off-the-record comment
my @loggedLines = ();
my $timePattern = '((\s|\d)\d\:(\s|\d)\d)'; # 3 parens
my @months = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);
@months == 12 || die;
my $monthsPattern = &MakePattern(@months);
foreach my $line (@lines)
	{
	if (&Trim($line) eq "") { $n++; $line = ""; }
	# **** BEGIN LOGGING AT Mon Feb 14 08:37:02 2005
	elsif ($line =~ m/\A\*\*\*\* BEGIN LOGGING AT /i) { $n++; $line = ""; }
	# **** ENDING LOGGING AT Mon Feb 14 10:22:09 2005
	elsif ($line =~ m/\A\*\*\*\* ENDING LOGGING AT /i) { $n++; $line = ""; }
	# Feb 14 08:37:02 -->     You are now talking on &arch
	# Feb 14 08:37:02 ---     Topic for &arch is W3C Architecture Mardi Gras Meeting
	# Feb 14 11:02:23 <dbooth>        This is an on-the-record comment
	# Feb 14 11:02:26 *       Yves This is an off-the-record comment
	elsif ($line =~ m/\A($monthsPattern)\s+\d+\s+\d+\:\d+\:\d+\s+/i) 
		{
		my $rest = $'; # All but the timestamp
		# Feb 14 08:37:02 -->     You are now talking on &arch
		# Feb 14 08:37:02 ---     Topic for &arch is W3C Architecture Mardi Gras Meeting
		if ($rest =~ m/\A\-\-/) { $n++; $line = ""; }
		# Feb 14 11:02:23 <dbooth>        This is an on-the-record comment
		elsif ($rest =~ m/\A\<$namePattern\>/i) 
			# &Trim() because the log includes extra spaces/tabs
			# after the <dbooth> in order to line up the text.
			# This means that without more sophisticated analysis
			# and processing here, space indentation will not
			# be recognized as indicating continuation lines.
			{ 
			my $name = $&; # <dbooth>
			my $statement = &Trim($');
			$n++; 
			$line = "$name $statement"; 
			}
		# Feb 14 11:02:26 *       Yves This is an off-the-record comment
		elsif ($rest =~ m/\A\*/) { $n++; $line = ""; }
		else { $line = &Trim($rest); } # Unrecognized line. Remove timestamp
		}
	else {} # Unrecognized line.  Retain as is.
	# warn "LINE: $line\n";
	push(@loggedLines, $line) if $line =~ m/\S/; # non-blank lines
	}
my $score = $n / $nLines;
# warn "XChat_Timestamped_Log_Format n: $n nLines: $nLines score: $score\n";
$all = join("\n", @loggedLines) . "\n";
return($score, $all);
}

##################################################################
########################## Mirc_Timestamped_Log_Format #########################
##################################################################
# Format from saving MIRC buffer.
sub Mirc_Timestamped_Log_Format
{
die if @_ != 1;
my ($all) = @_;
# Join continued lines:
$all =~ s/\n\ \ //g;
# Count the number of recognized lines
my @lines = grep {m/\S/} split(/\n/, $all); # Ignore empty lines
my $nLines = scalar(@lines);
my $n = 0;
# my $namePattern = '([\\w\\-]([\\w\\d\\-]*))';
# First line may be empty
if (@lines && &Trim($lines[0]) eq "")
	{
	$n++;
	shift @lines;
	}
# Second line may be:
#	Session Start: Thu Jun 24 09:22:36 2004
if (@lines && $lines[0] =~ m/\ASession Start\:/i)
	{
	$n++;
	shift @lines;
	}
# Third line may be:
#	Session Ident: &arch
if (@lines && $lines[0] =~ m/\ASession Ident\:/i)
	{
	$n++;
	shift @lines;
	}
# Last line may be:
#	Session Close: Thu Jun 24 09:23:59 2004
if (@lines && $lines[@lines-1] =~ m/\ASession Close\:/i)
	{
	$n++;
	pop @lines;
	}
# Count remaining lines that look reasonable
# [19:35] <Zakim> Steven should now be muted
# [19:36] <ph> http://lists.w3.org/Archives/Member/w3c-html-cg/2004JanMar/0038.html
# [19:36] * Zakim hears Steven's hand up
# [19:36] * Zakim sees Steven on the speaker queue
my @loggedLines = ();
my $timePattern = '((\s|\d)\d\:(\s|\d)\d)'; # 3 parens
foreach my $line (@lines)
	{
	# We may have start/stop messages embedded, such as:
	#	Session Close: Thu Jun 24 09:22:24 2004
	#	
	#	Session Start: Thu Jun 24 09:22:36 2004
	#	Session Ident: &arch
	if ($line =~ m/\ASession Close\:/i) { $n++; $line = ""; }
	elsif ($line =~ m/\ASession Start\:/i) { $n++; $line = ""; }
	elsif ($line =~ m/\ASession Ident\:/i) { $n++; $line = ""; }
	# * unlogged /me comment (delete)
	elsif ($line =~ m/\A(\[$timePattern\]\s)\*/i) { $n++; $line = ""; }
	# <ericn> Discussion on how to progress
	elsif ($line =~ s/\A(\[$timePattern\]\s)(\<$namePattern\>\s)/$5/i) { $n++; }
	else	{
		# warn "MIRC not match: $line\n";
		}
	# warn "LINE: $line\n";
	push(@loggedLines, $line) if $line =~ m/\S/;
	}
my $score = $n / $nLines;
# warn "Mirc_Text_Format n: $n nLines: $nLines score: $score\n";
$all = join("\n", @loggedLines) . "\n";
return($score, $all);
}

##################################################################
################## Irssi_ISO8601_Log_Text_Format #####################
##################################################################
# Example: http://lists.w3.org/Archives/Public/www-archive/2004Jan/att-0003/ExampleFormat-NormalizerHugoLogText.txt
# See also http://wiki.irssi.org/cgi-bin/twiki/view/Irssi/WindowLogging
sub OLD_Irssi_ISO8601_Log_Text_Format
{
die if @_ != 1;
my ($all) = @_;
# Join continued lines:
$all =~ s/\n\ \ //g;
# Count the number of recognized lines
my @lines = split(/\n/, $all);
my $nLines = scalar(@lines);
my $n = 0; # Number of lines of recognized format.
# my $namePattern = '([\\w\\-]([\\w\\d\\-\\.]*))';
# 2003-12-18T15:26:57-0500 
my $datePattern = '(\d\d\d\d\-(\ |\d)\d\-(\ |\d)\d)';	# 3 parens
my $timePattern = '((\s|\d)\d\:(\s|\d)\d\:(\s|\d)\d)';	# 4 parens
my $hourOffsetPattern = '((( |\-|\+)\d\d\d\d)?)';	# 3 parens
my $timestampPattern = $datePattern . "T" . $timePattern . $hourOffsetPattern;
# warn "timestampPattern: $timestampPattern namePattern: $namePattern\n";
my @linesOut = ();
while (@lines)
	{
	my $line = shift @lines;
	# 20:41:27 <ericn> Review of minutes 
	if (0) {}
	# Keep normal lines:
	# 2003-12-18T15:27:36-0500 <hugo> Hello.
	elsif ($line =~ s/\A$timestampPattern\s+(\<$namePattern\>)/$11/i)
		{ $n++; push(@linesOut, $line); }
	# Also keep comment lines.  They'll be removed later.
	# 2003-12-18T16:56:06-0500  * RRSAgent records action 4
	elsif ($line =~ s/\A$timestampPattern\s+(\*)/$11/i)
		{ $n++; push(@linesOut, $line); }
	# Recognize, but discard:
	# 2003-12-18T15:26:57-0500 !mcclure.w3.org hugo invited Zakim into channel #ws-arch.
	elsif ($line =~ m/\A$timestampPattern\s+\!/i)
		{ $n++; } 
	# Recognize, but discard:
	# 2003-12-18T15:27:30-0500 -!- dbooth [dbooth@18.29.0.30] has joined #ws-arch
	elsif ($line =~ m/\A$timestampPattern\s+\-\!\-/i)
		{ $n++; } 
	else	{
		# warn "UNRECOGNIZED LINE: $line\n";
		push(@linesOut, $line); # Keep unrecognized line
		}
	# warn "LINE: $line\n";
	}
$all = "\n" . join("\n", @linesOut) . "\n";
# warn "Irssi_ISO8601_Log_Text_Format n matches: $n\n";
my $score = $n / $nLines;
return($score, $all);
}

##################################################################
################## Irssi_ISO8601_Log_Text_Format #####################
##################################################################
# Example: http://lists.w3.org/Archives/Public/www-archive/2004Jan/att-0003/ExampleFormat-NormalizerHugoLogText.txt
# See also:
#   http://wiki.irssi.org/cgi-bin/twiki/view/Irssi/WindowLogging
#   http://www.cl.cam.ac.uk/~mgk25/iso-time.html
#   http://www.w3.org/TR/NOTE-datetime
# or search for ISO8601.
sub Irssi_ISO8601_Log_Text_Format
{
die if @_ != 1;
my ($all) = @_;
# Join continued lines:
$all =~ s/\n\ \ //g;
# die "all: $all\n";
# Count the number of recognized lines
my @lines = split(/\n/, $all);
my $nLines = scalar(@lines);
my $n = 0; # Number of lines of recognized format.
# my $namePattern = '([\\w\\-]([\\w\\d\\-\\.]*))';
# 2003-12-18T15:26:57.4321-0500 
# 2003-12-18T15:26:57,4321-0500 
# 2003-12-18T15:26:57-0500 
# 2003-12-18T15:26:57-05:00 
# 2003-12-18T15:26:57+0500 
# 2003-12-18T15:26:57Z
my $yearP = '\d\d\d\d';		# 2004
my $monP =  '\-?\d\d';		# -12
my $dayP =  '\-?\d\d';		# -18
my $hourP = '\d\d';		# 15
my $minP =  '\:?\d\d';		# :26
my $secP =  '\:?\d\d';		# :57
my $fracP = '[\.\,]\d+';	# .4321
my $tzhP =   '[\+\-]\d\d';	# -05
my $tzmP =  '\:?\d\d';		# :00
# This pattern is based on ISO8601 for timestamps, but permits the year, 
# month and day to be omitted, and requires at least the hours and minutes.
# It also permits the timezone designation to be omitted.
# $iso8601Pattern contains 7 parens:
my $iso8601Pattern = "($yearP$monP$dayP(T))?$hourP$minP($secP($fracP)?)?(Z|($tzhP($tzmP)?))?";
my $timestampPattern = $iso8601Pattern;
# warn "timestampPattern: $timestampPattern namePattern: $namePattern\n";
my @linesOut = ();
while (@lines)
	{
	my $wholeLine = shift @lines;
	my $line = $wholeLine;
	# Remove timestamp: 2003-12-18T15:27:36-0500
	if ($line !~ s/\A$timestampPattern(\s?)//i)
		{
		# warn "UNRECOGNIZED LINE: $wholeLine\n";
		push(@linesOut, $wholeLine); # Keep unrecognized line
		next;
		}
	# Keep normal lines:
	# 2003-12-18T15:27:36-0500 <hugo> Hello.
	if ($line =~ s/\A\s?\s?(\<$namePattern\>)/$1/i)
		{ $n++; push(@linesOut, $line); }
	# Also keep comment lines.  They'll be removed later.
	# 2003-12-18T16:56:06-0500  * RRSAgent records action 4
	elsif ($line =~ s/\A\s?\s?(\*)/$1/i)
		{ $n++; push(@linesOut, $line); }
	# Recognize, but discard:
	# 2003-12-18T15:26:57-0500 !mcclure.w3.org hugo invited Zakim into channel #ws-arch.
	elsif ($line =~ m/\A\s*\!/i)
		{ $n++; } 
	# Recognize, but discard:
	# 2003-12-18T15:27:30-0500 -!- dbooth [dbooth@18.29.0.30] has joined #ws-arch
	elsif ($line =~ m/\A\s*\-\!\-/i)
		{ $n++; } 
	else	{
		# warn "UNRECOGNIZED LINE: $line\n";
		push(@linesOut, $line); # Keep unrecognized line
		}
	# warn "LINE: $line\n";
	}
$all = "\n" . join("\n", @linesOut) . "\n";
# warn "Irssi_ISO8601_Log_Text_Format n matches: $n nLines: $nLines\n";
my $score = $n / $nLines;
return($score, $all);
}

##################################################################
########################## RRSAgent_Text_Format #########################
##################################################################
# Example: http://www.w3.org/2003/03/03-ws-desc-irc.txt
sub RRSAgent_Text_Format
{
die if @_ != 1;
my ($all) = @_;
# Join continued lines:
$all =~ s/\n\ \ //g;
# Count the number of recognized lines
my @lines = split(/\n/, $all);
my $n = 0;
# my $namePattern = '([\\w\\-]([\\w\\d\\-]*))';
my $timePattern = '((\s|\d)\d\:(\s|\d)\d\:(\s|\d)\d)';
foreach my $line (@lines)
	{
	# 20:41:27 <ericn> Review of minutes 
	$n++ if $line =~ s/\A$timePattern\s+(\<$namePattern\>\s)/$5/i;
	# warn "LINE: $line\n";
	}
$all = "\n" . join("\n", @lines) . "\n";
# warn "RRSAgent_Text_Format n matches: $n\n";
my $score = $n / @lines;
return($score, $all);
}

##################################################################
########################## RRSAgent_HTML_Format #########################
##################################################################
# Example: http://www.w3.org/2003/03/03-ws-desc-irc.html
sub RRSAgent_HTML_Format
{
die if @_ != 1;
my ($all) = @_;
my @lines = split(/\n/, $all);
my $n = 0;
# my $namePattern = '([\\w\\-]([\\w\\d\\-\\.]*))';
my $idPattern ='[0-9a-zA-Z;/?\\:@&=+\\$\\.\\-_!~*\\\'()%]+';	# 0 parens
my $timePattern = '((\s|\d)\d\:(\s|\d)\d\:(\s|\d)\d)';		# 4 parens
my @boilerplateLines = split(/\s*\n\s*/,
	'<?xml version="1.0" encoding="UTF-8"?>
	<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
	    "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
	<html xmlns="http://www.w3.org/1999/xhtml">
	<head>
	 <title>IRC log of arch on 2005-02-22</title>
	<meta name="generator" content="&#36;Id: logger,v 1.75.1.56 2005/02/14 18:10:52 swick Exp &#36;" />
	 <style type="text/css">
	  .IRC { font-family: sans-serif }
	 </style>
	</head>
	<body>
	<h1>IRC log of arch on 2005-02-22</h1>
	<p><em>Timestamps are in UTC.</em></p>
	<dl class="IRC">
	</dl>
	</body>
	</html>');
# Turn the above literal strings into patterns:
my @boilerPatterns = map { $_ = quotemeta($_); s/\barch\b/\\S+/; s/\d+/\\d+/g; $_ } @boilerplateLines;
# die "boilerPatterns:\n" . join("\n\t", @boilerPatterns) . "\n";
my $boilerPattern = join("|", @boilerPatterns);
my $result = "";
foreach my $line (@lines)
	{
	# <dt id="T14-35-34">14:35:34 [dbooth]</dt><dd>Gudge: why not sufficient?</dd>
	# <dt id="T03-19-51">03:19:51 [MSEder]</dt><dd>MSEder has joined #ws-addr</dd>
	# <dt id="T13-03-57-1">13:03:57 [Zakim]</dt><dd>ok, MSM; the call is being made</dd>
	# New: /\<dt/\sid/\=/\"T\d\d\-\d\d\-\d\d(\-\d+)?\"\>\d\d\:\d\d\:\d\d\s\[$namePattern\]\<\/dt\>\<dd\>(.*)\<\/dd\>/
	# if ($line =~ s/\A\<dt\s+id\=\"($namePattern)\"\>$timePattern\s+\[($namePattern)\]\<\/dt\>\s*\<dd\>(.*)\<\/dd\>\s*\Z/\<$8\> $11/i)
	# if ($line =~ s/\A\<dt\s+id\=\"($idPattern)\"\>$timePattern\s+\[($namePattern)\]\<\/dt\>\s*\<dd\>(.*)\<\/dd\>\s*\Z/\<$6\> $7/i)
	if ($line =~ s/\A\<dt\s+id\=\"($idPattern)\"\>$timePattern\s+\[($namePattern)\]\<\/dt\>\s*\<dd\>(.*)\<\/dd\>\s*\Z/\<$6\> $7/i)
		{
		my $name = $6;
		my $rest = $7;
		$n++;
		# warn "MATCHED: $line\n";
		# Strip out embedded HTML tags:
		while ($rest =~ s/\<[a-zA-Z0-9\-\_\/]+[^\<\>]*\>//)
			{
			# warn "Stripped embedded HTML tag: $&\n";
			}
		$line = "<$name> $rest";
		}
	elsif ($line =~ s/\A\s*$boilerPattern\s*\Z//) { $n++; }
	else 	{ 
		# warn "NO match: $line\n"; 
		}
	$result .= $line;
	}
$all = "\n" . join("\n", @lines) . "\n";
# warn "RRSAgent_HTML_Format n matches: $n\n";
my $score = $n / @lines;
# Unescape &entity;
$all =~ s/\&amp\;/\&/g;
$all =~ s/\&lt\;/\</g;
$all =~ s/\&gt\;/\>/g;
$all =~ s/\&quot\;/\"/g;
return($score, $all);
}

##################################################################
########################## RRSAgent_Visible_HTML_Text_Paste_Format #########################
##################################################################
# This is for the format that is visible in the browser when RRSAgent's HTML
# is displayed.  I.e., when you view the (HTML) document in a browser, and 
# then copy and paste the text from the browser window, it discards
# the HTML code and copies only the displayed text.
# Example: http://lists.w3.org/Archives/Public/www-archive/2004Jan/att-0002/ExampleFormat-RRSAgent_Visible_HTML_Text_Paste_Format.txt
sub RRSAgent_Visible_HTML_Text_Paste_Format
{
die if @_ != 1;
my ($all) = @_;
my @lines = split(/\n/, $all);
my $nLines = scalar(@lines);
my $n = 0;
# my $namePattern = '([\\w\\-]([\\w\\d\\-]*))';
my $timePattern = '((\s|\d)\d\:(\s|\d)\d\:(\s|\d)\d)'; # 4 parens
my $done = "";
# while($all =~ s/\A((.*\n)(.*\n))//)	# Grab next two lines
my $i = 0;
while ($i < (@lines-1))
	{
	# my $linePair = $1;
	my $line1 = &Trim($lines[$i]);
	my $line2 = &Trim($lines[$i+1]);
	# This format uses line pairs:
	# 	14:43:30 [Arthur]
	# 	If it's abstract, it goes into portType 
	# if ($linePair =~ s/\A($timePattern)\s+\[($namePattern)\][\ \t]*\n/\<$6\> /i)
	my $name = "";
	if ($line1 =~ m/\A($timePattern)\s+\[($namePattern)\]\Z/i
		&& ($name = $6)	# Assignment!  Save that value!
		&& $line2 !~ m/\A($timePattern)\s+\[($namePattern)\]/i)
		{
		# warn "MATCH: name: $name line2: $line2\n";
		$done .= "<$name> $line2\n";
		$n += 2;
		$i++;
		}
	elsif ($line1 eq ""
		|| $line1 eq "Timestamps are in UTC."
		|| $line1 =~ m/\AIRC log of /i) 
		{ 
		# warn "IGNORING: line: $lines[$i]\n";
		$n++; 
		}
	else	{
		# warn "NO match: line: $lines[$i]\n";
		$done .= $lines[$i] . "\n";
		}
	$i++;
	}
$done .= $lines[$i] . "\n" if $i < @lines; # Remaining line
$all = $done;
# warn "RRSAgent_Visible_HTML_Text_Paste_Format n matches: $n\n";
my $score = $n / $nLines;
# &Die("Score: $score n: $n nLines: $nLines\n");
return($score, $all);
}

##################################################################
########################## Yahoo_IM_Format #########################
##################################################################
sub Yahoo_IM_Format
{
die if @_ != 1;
my ($all) = @_;
my @lines = split(/\n/, $all);
my $n = 0;
# my $namePattern = '([\\w\\-]([\\w\\d\\-]*))';
foreach my $line (@lines)
	{
	$n++ if $line =~ s/\A($namePattern)\:\s/\<$1\> /i;
	# warn "LINE: $line\n";
	}
$all = "\n" . join("\n", @lines) . "\n";
# warn "Yahoo_IM_Format n matches: $n\n";
my $score = $n / @lines;
return($score, $all);
}

##################################################################
########################## Plain_Text_Format #########################
##################################################################
# This is just a plain text file of notes made by the scribe.
# This format does NOT use timestamps, nor does it use <speakerName>
# at the beginning of each line.  It does still use the "dbooth: ..."
# convention to indicate what someone said.
sub Plain_Text_Format
{
die if @_ != 1;
my ($all) = @_;
# Join continued lines:
# Count the number of recognized lines
my @lines = split(/\n/, $all);
my $n = 0;
my $timePattern = '((\s|\d)\d\:(\s|\d)\d\:(\s|\d)\d)';
# my $namePattern = '([\\w\\-]([\\w\\d\\-\\.]*))';
for (my $i=0; $i<@lines; $i++)
	{
	# Lines should NOT have timestamps:
	# 	20:41:27 <ericn> Review of minutes 
	next if $lines[$i] =~ m/$timePattern\s+/i;
	# Lines should NOT contain <speakerName>:
	# 	<ericn> Review of minutes 
	next if $lines[$i] =~ m/(\<$namePattern\>\s)/i;
	# Line should NOT have [name] unless it pertains to an action item.
	# Check the current line and previous line for the word ACTION,
	# because the action status [PENDING] could follow the ACTION line.
	next if $lines[$i] =~ m/(\[$namePattern\]\s)/i
		&&  $lines[$i] !~ m/\bACTION\b/i
		&&  ($i == 0 || ($lines[$i] !~ m/\bACTION\b/i));
	# warn "LINE: $lines[$i]\n";
	$n++;
	}
# Now add "<scribe> " to the beginning of each line, to make it like
# the standard format.
for (my $i=0; $i<@lines; $i++)
	{
	$lines[$i] = "<scribe> " . $lines[$i];
	}
$all = "\n" . join("\n", @lines) . "\n";
# warn "Plain_Text_Format n matches: $n\n";
my $score = $n / @lines;
# Artificially downgrade the score, so that more specific formats
# like Yahoo_IM_Format will win if they both match:
$score = $score * 0.95;
return($score, $all);
}

##################################################################
########################## Normalized_Format #########################
##################################################################
# Already normalized.  No-op.
sub Normalized_Format
{
die if @_ != 1;
my ($all) = @_;
# Count the number of recognized lines
my @lines = grep {m/\S/} split(/\n/, $all); # Ignore empty lines
my $n = 0;
# my $namePattern = '([\\w\\-]([\\w\\d\\-]*))';
my $timePattern = '((\s|\d)\d\:(\s|\d)\d\:(\s|\d)\d)';
foreach my $line (@lines)
	{
	# <ericn> Review of minutes 
	if ($line =~ m/\A(\<$namePattern\>\s)/i)
		{
		$n++;
		# warn "Normalized MATCH: $line\n";
		}
	else	{
		# warn "NO MATCH: $line\n";
		}
	# warn "LINE: $line\n";
	}
# No change to $all
my $score = $n / @lines;
return($score, $all);
}


##################################################################
########################## ProbablyUsesImplicitContinuations #########################
##################################################################
# Guess whether the input probably uses implicit continuation lines.
# The implicit continuation style is like:
# 	<dbooth> Amy: Now is the time
# 	<dbooth> for all good men and women
# 	<dbooth> to come to the aid
# 	<dbooth> of their party.
# Note that there is no extra space setting off the continuation lines.
# This style is ambiguous, because we can't distinguish between the
# continuation of the previous speaker's statement and a new statement made
# by the scribe.
#
# The <dbooth>'s should have already been changed to <scribe> prior 
# to calling this function.
sub ProbablyUsesImplicitContinuations
{
die if @_ != 1;
my ($all) = @_;
$all = &IgnoreGarbage($all);
my @lines = split(/\n/, $all);
my @t = @lines;
# Blank lines:
@t = grep {!m/\A\s*\Z/} @t;
# Only consider scribe statements
# 	<scribe> whatever
@t = grep {m/\A\<scribe\>/i} @t;
# Don't count action lines
# 	<dbooth> [DONE] ACTION: ...
@t = grep {!m/\bACTION\b/i} @t;
# Don't count empty statements
# 	<dbooth> 
# @t = grep {!m/\A\<[a-zA-Z0-9\-_\.]+\>\s*\Z/} @t;
@t = grep {!m/\A\<scribe\>\s*\Z/i} @t;
my $nTotal = scalar(@t);
 # 	<dbooth> Amy: Now is the time (EXPLICIT SPEAKER)
 # @t = grep {!m/\A\<[a-zA-Z0-9\-_\.]+\>(\s?\s?)[a-zA-Z0-9\-_\.]+\s*\:/i} @t;
 @t = grep {!m/\A\<scribe\>(\s?\s?)[a-zA-Z0-9\-_\.]+\s*\:/i} @t;
my $nSpeaker = $nTotal - scalar(@t);
 # 	<dbooth>  for all good men and women  (EXPLICIT CONTINUATION)
 # @t = grep {!m/\A\<[a-zA-Z0-9\-_\.]+\>(\s\s\s*)/} @t;
 @t = grep {!m/\A\<scribe\>(\s\s\s*)/i} @t;
 # 	<dbooth> ... for all good men and women  (EXPLICIT CONTINUATION)
 # @t = grep {!m/\A\<[a-zA-Z0-9\-_\.]+\>(\s*)\.\./} @t;
 @t = grep {!m/\A\<scribe\>(\s*)\.\./i} @t;
my $nExpCont = $nTotal - ($nSpeaker + scalar(@t));
 # Remaining lines are potentially implicit continuation lines.
my $nPossCont = scalar(@t);
die if $nPossCont + $nExpCont + $nSpeaker != $nTotal;
# warn "nTotal: $nTotal nSpeaker: $nSpeaker nExpCont: $nExpCont nPossCont: $nPossCont\n";
# warn "Possible continuations: ", join("\n", @t), "\n\n";
# Guess the format
my $result = 0;
if ($nPossCont == 0)
	{
	$result = 0;
	}
# Mostly explicit speaker lines?
elsif ($nSpeaker/$nTotal >= 0.8)
	{
	if ($nExpCont/$nPossCont < 0.2) { $result = 1; }
	else { $result = 0; }
	}
elsif ($nExpCont/$nPossCont < 0.05) { $result = 1; }
# warn "ProbablyUsesImplicitContinuations returning: $result\n";
return $result;
}

##################################################################
########################## ExpandImplicitContinuations #########################
##################################################################
# NOTE: This should be called AFTER action item processing, so that "ACTION"
# is already at the beginning of the line: 
#	<scribe> ACTION DONE: ...
# instead of:
#	<scribe> DONE ACTION: ...
# Some of the possibilities handled:
# 	<scribe> ACTION: ... 
# 	<scribe>Amy: Now is the time (typo: missing space)
# 	<scribe>  for all good men and women (explicit continuation)
# 	<scribe> Joe: Now is the time (new speaker)
# 	<scribe>  for all good men and women
# 	<scribe>  Mary: Now is the time (typo: extra space)
# 	<scribe>  for all good men and women (explicit continuation)
# 	<scribe> Frank: Now is the time (typo: extra space)
# 	<scribe> for all good men and women (IMPLICIT continuation)
#	<scribe> Scores were: (normal statement)
# 	<scribe>   Red: 4  (tabular data; continuation)
sub ExpandImplicitContinuations
{
die if @_ != 1;
my ($all) = @_;
my @lines = split(/\n/, $all);
my $inContinuation = 0;
my $inStatement = 0;
for (my $i=0; $i<@lines; $i++)
	{
	# warn "LINE: $lines[$i]\n";
	# Skip blank lines:
	next if ($lines[$i] =~ m/\A\s*\Z/);
	# Skip lines not starting with <scribe>:
	next if ($lines[$i] !~ m/\A\<scribe\>(\s*)/i);
	# Line starts with <scribe>
	my $spaces = $1;
	my $rest = $';
	$spaces =~ s/\A ?\t/  \t/; # Initial tab forces continuation
	# Explicit continuation already:
	# 	<scribe> Amy: ... for all good men and women
	next if ($rest =~ m/\A\s*\.\./);
	# <scribe> ACTION: ...
	if ($rest =~ m/\AACTION\b/i)
		{
		$inContinuation = 0;
		next;
		}
	# <scribe>   Red: 4
	# More than one extra blank?  
	if ($inContinuation && length($spaces) > 2)
		{
		# Must be continuation of formatted text (such as a table).
		# Do nothing, because leading blank already means continuation.
		# (Though $spaces may have changed slightly if there was a tab.)
		$lines[$i] = "<scribe>$spaces$rest";
		next;
		}
	# 	<scribe> Amy: Now is the time
	# 	<scribe> ACTION: ...
	if ($rest =~ m/\A([a-zA-Z0-9\-_\.]+)( ?):/i)
		{
		# Not a continuation line.  Either new speaker or stop word.
		my $speaker = $1;
		my $newRest = $';
		$lines[$i] = "<scribe> $speaker\:$newRest";
		# New speaker starts a statement.
		# Stop word is a non-speaker, and thus terminates 
		# a continuing statement.
		my $lcSpeaker = &LC($speaker);
		$inStatement = $lcSpeaker eq "chair" 
				|| $lcSpeaker eq "scribe"
				|| !exists($stopList{$lcSpeaker});
		next;
		}
	# Exactly one extra blank?  
	# <scribe>  for all good men and women
	next if (length($spaces) == 2); # Already a continuation line
	# Otherwise it's a continuation if we're $inStatement
	if ($inStatement)
		{
		# <scribe> for all good men and women
		# Implicit continuation line!  Add leading blank:
		# warn "Reformatting implicit continuation line: <scribe>  $rest\n";
		$lines[$i] = "<scribe>  $rest";
		}
	}
$all = "\n" . join("\n", @lines) . "\n";
return($all);
}

##################################################################
##################### GetTemplate ####################
##################################################################
sub GetTemplate
{
@_ == 1 || die;
my ($templateFile) = @_;
open(TFILE,"<$templateFile") || return "";
my $template = join("",<TFILE>);
$template =~ s/\r//g;
close(TFILE);
return $template;
}

##################################################################
######################## GetDate ####################
##################################################################
# Grab date from $all or IRC log name or default to today's date.
sub GetDate
{
@_ == 2 || die;
my ($all, $logURL) = @_;
my @days = qw(Sun Mon Tue Wed Thu Fri Sat); 
@days == 7 || die;
# English-only month names :(
my @months = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);
my @lcMonths = @months;  # Lower case, length 3
@lcMonths = map {tr/A-Z/a-z/; s/\A(...).*\Z/$1/; $_} @lcMonths;
@months == 12 || die;
@lcMonths == 12 || die;
my %monthNumbers = map {($lcMonths[$_], $_+1)} (0 .. 11);
# warn "GetDate monthNumbers: ",join(" ",%monthNumbers),"\n";
my @date = ();
  # Look for Date: 12 Sep 2002
  {
    if ($all =~ s/\n\<$namePattern\>\s*(Date)\s*\:\s*(.*)\n/\n/i)
	{
	# Parse date from input.
	# I should have used a library function for this, but I wrote
	# this without net access, so I couldn't get one.
	my $d = &Trim($2);
	my @words = split(/[^0-9a-zA-Z]+/, $d);
	if (@words != 3) {
	    &Warn("WARNING: Date not understood: $d\n");
	    next;
	}
	my $correctFormat = "Date command/format should be like \"Date: 31 Jan 2004\"";
	my ($mday, $TMon, $year) = @words;
	my $tmon = $TMon;	# Lower case, truncated version
	$tmon =~ tr/A-Z/a-z/;
	$tmon =~ s/\A(...).*\Z/$1/; # Truncate to length 3
	unless (exists($monthNumbers{$tmon})) {
	    &Warn("WARNING: Could not parse date.  Unknown month name \"$TMon\": $d\nFormat should be like \"Date: 31 Jan 2004\"\n");
	    next;
	}
	my $mon = $monthNumbers{$tmon};
	($mon > 0 && $mon < 13) || die; # Internal error.
	unless (($mday > 0 && $mday < 32)) {
	    &Warn("WARNING: Bad day of month \"$mday\" (should be >0 && <32): $d\n$correctFormat\n");
	    next;
	}
	unless (($year > 2000 && $year < 2100)) {
	    &Warn("WARNING: Bad year \"$year\" (should be >2000 && <2100): $d\n$correctFormat\n");
	    next;
	}
	my $day0 = sprintf("%02d", $mday);
	my $mon0 = sprintf("%02d", $mon);
	my $alphaMonth = $months[$mon-1];
	&Warn("Found Date: $day0 $alphaMonth $year\n");
	@date = ($day0, $mon0, $year, $months[$mon-1]);
	}
    }

  # Figure out date from IRC log name:
  {
    next if @date;
    if ($logURL =~ m/\Ahttp\:\/\/(www\.)?w3\.org\/(\d+)\/(\d+)\/(\d+).+\-irc/i)
	{
	my $year = $2;
	my $mon = $3;
	my $mday = $4;
	($mon > 0 && $mon < 13) || die;
	($year > 2000 && $year < 2100) || die;
	($mday > 0 && $mday < 32) || die;
	my $day0 = sprintf("%02d", $mday);
	my $mon0 = sprintf("%02d", $mon);
	@date = ($day0, $mon0, $year, $months[$mon-1]);
	&Warn("Got date from IRC log name: $day0 " . $months[$mon-1] . " $year\n");
	}
else
	{
	&Warn("\nWARNING: No date found!  Assuming today.  (Hint: Specify\n");
	&Warn("the W3C IRC log URL, and the date will be determined from that.)\n");
	&Warn("Or specify the date like this:\n");
	&Warn("<dbooth> Date: 12 Sep 2002\n\n");
	# Assume today's date by default.
	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
	$mon++;	# put in range [1..12] instead of [0..11].
	($mon > 0 && $mon < 13) || die;
	$year += 1900;
	($year > 2000 && $year < 2100) || die;
	($mday > 0 && $mday < 32) || die;
	my $day0 = sprintf("%02d", $mday);
	my $mon0 = sprintf("%02d", $mon);
	@date = ($day0, $mon0, $year, $months[$mon-1]);
	}
    }
# warn "GetDate Returning date info: @date\n";
return @date;
}



##################################################################
###################### GetNames ######################
##################################################################
# Look for people in IRC log.
sub GetNames
{
@_ == 1 || die;
my($all) = @_;

# Some important data/constants:
my @rooms = qw(MIT308 MIT531 Stata531 SophiaSofa);

my @stopList = qw(a q on Re items Zakim Topic muted and agenda Regrets http the
	RRSAgent Loggy Zakim2 ACTION Chair Meeting DONE PENDING WITHDRAWN
	Scribe 00AM 00PM P IRC Topics DROPPED ger-logger
	yes no abstain Consensus Participants Question RESOLVED strategy
	AGREED Date queue no one in XachBot got it WARNING Present Agenda RESOLUTION);
@stopList = (@stopList, @rooms);
@stopList = map {tr/A-Z/a-z/; $_} @stopList;	# Make stopList lower case
my %stopList = map {($_,$_)} @stopList;

# Easier pattern matching:
$all = "\n" . $all . "\n";

# Now start collecting names.
my %names =  ();
my $t; # Temp

# 	  ...something.html Simon's two minutes
$t = $all;
# my $namePattern = '([\\w\\-]([\\w\\d\\-]*))';
# warn "namePattern: $namePattern\n";
while($t =~ s/\b($namePattern)\'s\s+(2|two)\s+ minutes/ /i)
	{
	my $n = $1;
	$names{$n} = $n;
	}

#	<dbooth> MC: I have integrated most of the coments i received 
$t = $all;
while($t =~ s/\n\<((\w|\-)+)\>(\ +)((\w|\-)+)\:/\n/i)
	{
	my $n = $4;
	next if exists($names{$n});
	# warn "Matched #	<dbooth> $n" . ": ...\n";
	$names{$n} = $n;
	}
# warn "names: ",join(" ",keys %names),"\n";

#	<Steven> Hello 
$t = $all;
while($t =~ s/\n\<((\w|\-)+)\>/\n/i)
	{
	my $n = $1;
	next if exists($names{$n});
	# warn "Matched #	<$n>\n";
	$names{$n} = $n;
	# warn "Found name: $n\n";
	}

#	Zakim sees 4 items remaining on the agenda
$t = $all;
while ($t =~ s/\n\s*((\<Zakim\>)|(\*\s*Zakim\s)).*\b(agenda|agendum)\b.*\n/\n/i)
	{
	my $match = &Trim($&);
	$match = $match;
	# warn "DELETED: $match\n";
	}

#	<Zakim> I see no one on the speaker queue
#	<Zakim> I see Hugo, Yves, Philippe on the speaker queue
#	<Zakim> I see MIT308, Ivan, Marie-Claire, Steven, Janet, EricM
#	<Zakim> On the phone I see Joseph, m3mSEA, MIT308, Marja
#	<Zakim> On IRC I see Nobu, SusanL, RRSAgent, ht, Ian, ericP
#	<Zakim> ... simonMIT, XachBot
#	<Zakim> I see MIT308, Ivan, Marie-Claire, Steven, Janet, EricM
#	<Zakim> MIT308 has Martin, Ted, Ralph, Alan, EricP, Vivien
#	<Zakim> +Carine, Yves, Hugo; got it
#
# Delete "on the speaker queue" from the ends of the lines,
# to prevent those words being mistaken for names.
while($t =~ s/(\n\<Zakim\>\s+.*)on\s+the\s+speaker\s+queue\s*\n/$1\n/i)
        {
        warn "Deleted 'on the speaker queue'\n";
        }
# Collect names
while($t =~ s/\n\<Zakim\>\s+((([\w\d\_][\w\d\_\-]+) has\s+)|(I see\s+)|(On the phone I see\s+)|(On IRC I see\s+)|(\.\.\.\s+)|(\+))(.*)\n/\n/i)
	{
	my $list = &Trim($9);
	my @names = split(/[^\w\-]+/, $list);
	@names = map {&Trim($_)} @names;
	@names = grep {$_} @names;
	# warn "Matched #       <Zakim> I see: @names\n";
	foreach my $n (@names)
		{
		next if exists($names{$n});
		$names{$n} = $n;
		}
	}

# Make the keys all lower case, so that they'll match:
%names = map {my $oldn = $_; tr/A-Z/a-z/; ($_, $names{$oldn})} keys %names;
# warn "Lower case name keys:\n";
foreach my $n (sort keys %names)
	{
	# warn "	$n	$names{$n}\n";
	}

# Eliminate non-names
foreach my $n (keys %names)
	{
	# Filter out names in stopList
	if (exists($stopList{$n})) { delete $names{$n}; }
	# Filter out names less than two chars in length:
	elsif (length($n) < 2) { delete $names{$n}; }
	# Filter out names not starting with a letter
	elsif ($names{$n} !~ m/\A[a-zA-Z]/i) { delete $names{$n}; }
	}

# Make a list of unique names for the attendee list:
my %uniqNames = ();
foreach my $n (values %names)
	{
	$uniqNames{$n} = $n;
	}

# Make a list of all names seen (all variations) in lower case:
my %allNames = ();
foreach my $n (%names)
	{
	my $name = $n;
	$name =~ tr/A-Z/a-z/;
	$allNames{$name} = $name;
	}
@allNames = sort keys %allNames;
# warn "allNames: @allNames\n";
my @allNameRefs = map { \$_ } @allNames;

# Canonicalize the names in the IRC:

my @sortedUniqNames = sort values %uniqNames;
# warn "EMPTY synonyms\n" if !%synonyms;
return($all, \@allNameRefs, @sortedUniqNames);
}

##################################################################
################ LC ####################
##################################################################
# Lower Case.  Return a lower case version of the given string.
sub LC
{
@_ == 1 || die;
my ($s) = @_;	# Make a copy
$s =~ tr/A-Z/a-z/;
return $s;
}

##################################################################
################ Trim ####################
##################################################################
# Trim leading and trailing blanks from the given string.
sub Trim
{
@_ == 1 || die;
my ($s) = @_;
$s =~ s/\A\s+//;
$s =~ s/\s+\Z//;
return $s;
}

##################################################################
################ DefaultTemplate ####################
##################################################################
sub DefaultTemplate
{
return &PublicTemplate();
}

##################################################################
####################### SampleInput ##############################
##################################################################
sub SampleInput
{
my $sampleInput = <<'SampleInput-EOF'
<dbooth> Scribe: David Booth
<dbooth> ScribeNick: dbooth
<dbooth> Chair: Jonathan
<dbooth> Meeting: Weekly Baking Club Meeting
<hugo> Agenda: http//www.example.com/agendas/2002-12-05-agenda.html
<dbooth> Date: 05 Dec 2002
<dbooth> Topic: Review of Action Items
<Philippe> PENDING ACTION: Barbara to bake 3 pies 
<Philippe> DONE ACTION: David to make ice cream 
<Philippe> ACTION: David to make frosting -- DONE
<Philippe> ACTION: David to make candles  *DONE*
<Philippe> ACTION: David to make world peace  *PENDING*
<dbooth> Topic: What to Eat for Dessert
<dbooth> Joseph: I think that we should all eat cake
<dbooth> ... with ice creme.
<dbooth> s/creme/cream/
<Philippe> That's a good idea
<dbooth> ACTION: dbooth to send a message to himself about action items
<dbooth> Topic: Next Week's Meeting
<Philippe> I think we should do this again next week.
<Jonathan> Sounds good to me.
<dbooth> rrsagent, where am i?
<RRSAgent> I am logging.
<RRSAgent> See http://www.w3.org/2002/11/07-ws-arch-irc#T13-59-36
SampleInput-EOF
;
return $sampleInput;
}

##################################################################
###################### GetEmbeddedTemplates ############################
##################################################################
# For new template processing.  Test with NewTemplate.htm
# Remove and return all embedded templates from given $text.  Returns:
#	$newText     -- $text after removing templates
#	%templateMap -- Map from templateNames to templates
# Returned templates also have any embedded templates removed.
sub GetEmbeddedTemplates
{
@_ == 1 || die;
my ($text) = @_;
if ($text =~ s/\<\!\-\-BEGIN\:(\w+)\-\-\>((.|\n)*?)\<\!\-\-END\:\1\-\-\>//)
	{
	my $templateName = $1;
	my $template = $2; 
	my ($newTemplate, %nestedTemplates) = &GetEmbeddedTemplates($template);
	my ($newText, %otherTemplates) = &GetEmbeddedTemplates($text);
	my %templateMap = ($templateName, $newTemplate, %nestedTemplates, %otherTemplates);
	return($newText, %templateMap);
	}
else	{
	return($text, ());
	}
}

##################################################################
###################### PlainTemplate ############################
##################################################################
sub PlainTemplate
{
my $template = <<'PlainTemplate-EOF'
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" "http://www.w3.org/TR/html4/loose.dtd">
<html lang='en'>
<head>
  <title>SV_MEETING_TITLE &mdash; SV_MEETING_DAY SV_MEETING_MONTH_ALPHA SV_MEETING_YEAR</title>
  <link type="text/css" rel="STYLESHEET" href="http://www.w3.org/StyleSheets/base.css">
  <link type="text/css" rel="STYLESHEET" href="http://www.w3.org/StyleSheets/public.css">
  <link type="text/css" rel="STYLESHEET" href="http://www.w3.org/2004/02/minutes-style.css">
  <meta content="SV_MEETING_TITLE" name="Title">  
  <meta content="text/html; charset=iso-8859-1" http-equiv="Content-Type">
</head>

<body>
SV_DRAFT_WARNING
<h1>SV_MEETING_TITLE</h1>
<h2>SV_MEETING_DAY SV_MEETING_MONTH_ALPHA SV_MEETING_YEAR</h2>

SV_FORMATTED_AGENDA_LINK

SV_FORMATTED_IRC_URL

<h2><a name="attendees">Attendees</a></h2>

<div class="intro">
<dl>
<dt>Present</dt>
<dd>SV_PRESENT_ATTENDEES</dd>
<dt>Regrets</dt>
<dd>SV_REGRETS</dd>
<dt>Chair</dt>
<dd>SV_MEETING_CHAIR </dd>
<dt>Scribe</dt>
<dd>SV_MEETING_SCRIBE</dd>
</dl>
</div>

<h2>Contents</h2>
<ul>
  <li><a href="#agenda">Topics</a>
	<ol>
	SV_MEETING_AGENDA
	</ol>
  </li>
  <li><a href="#ActionSummary">Summary of Action Items</a></li>
</ul>
<hr>
<div class="meeting">
SV_AGENDA_BODIES
</div>
<h2><a name="ActionSummary">Summary of Action Items</a></h2>
<!-- Action Items -->
SV_ACTION_ITEMS

[End of minutes] <br>
<hr>

<address>
  Minutes formatted by David Booth's 
  <a href="http://dev.w3.org/cvsweb/~checkout~/2002/scribe/scribedoc.htm">scribe.perl</a> version SCRIBEPERL_VERSION (<a href="http://dev.w3.org/cvsweb/2002/scribe/">CVS log</a>)<br>
  $Date: 2011-05-12 12:01:43 $ 
</address>
<div class="diagnostics">
SV_DIAGNOSTICS
</div>
</body>
</html>
PlainTemplate-EOF
;
return $template;
}

##################################################################
###################### PublicTemplate ############################
##################################################################
sub PublicTemplate
{
my $template = <<'PublicTemplate-EOF'
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" "http://www.w3.org/TR/html4/loose.dtd">
<html lang='en'>
<head>
  <title>SV_MEETING_TITLE -- SV_MEETING_DAY SV_MEETING_MONTH_ALPHA SV_MEETING_YEAR</title>
  <link type="text/css" rel="STYLESHEET" href="http://www.w3.org/StyleSheets/base.css">
  <link type="text/css" rel="STYLESHEET" href="http://www.w3.org/StyleSheets/public.css">
  <link type="text/css" rel="STYLESHEET" href="http://www.w3.org/2004/02/minutes-style.css">
  <meta content="SV_MEETING_TITLE" name="Title">  
  <meta content="text/html; charset=iso-8859-1" http-equiv="Content-Type">
</head>

<body>
<p><a href="http://www.w3.org/"><img src="http://www.w3.org/Icons/w3c_home" alt="W3C" border="0"
height="48" width="72"></a> 

</p>

SV_DRAFT_WARNING
<h1>SV_MEETING_TITLE</h1>
<h2>SV_MEETING_DAY SV_MEETING_MONTH_ALPHA SV_MEETING_YEAR</h2>

SV_FORMATTED_AGENDA_LINK

SV_FORMATTED_IRC_URL

<h2><a name="attendees">Attendees</a></h2>

<div class="intro">
<dl>
<dt>Present</dt>
<dd>SV_PRESENT_ATTENDEES</dd>
<dt>Regrets</dt>
<dd>SV_REGRETS</dd>
<dt>Chair</dt>
<dd>SV_MEETING_CHAIR </dd>
<dt>Scribe</dt>
<dd>SV_MEETING_SCRIBE</dd>
</dl>
</div>

<h2>Contents</h2>
<ul>
  <li><a href="#agenda">Topics</a>
	<ol>
	SV_MEETING_AGENDA
	</ol>
  </li>
  <li><a href="#ActionSummary">Summary of Action Items</a></li>
</ul>
<hr>
<div class="meeting">
SV_AGENDA_BODIES
</div>
<h2><a name="ActionSummary">Summary of Action Items</a></h2>
<!-- Action Items -->
SV_ACTION_ITEMS

[End of minutes] <br>
<hr>

<address>
  Minutes formatted by David Booth's 
  <a href="http://dev.w3.org/cvsweb/~checkout~/2002/scribe/scribedoc.htm">scribe.perl</a> version SCRIBEPERL_VERSION (<a href="http://dev.w3.org/cvsweb/2002/scribe/">CVS log</a>)<br>
  $Date: 2011-05-12 12:01:43 $ 
</address>
<div class="diagnostics">
SV_DIAGNOSTICS
</div>
</body>
</html>
PublicTemplate-EOF
;
return $template;
}

##################################################################
###################### MemberTemplate ############################
##################################################################
sub MemberTemplate
{
my $template = <<'MemberTemplate-EOF'
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" "http://www.w3.org/TR/html4/loose.dtd">
<html lang="en">
<head>
  <title>SV_MEETING_TITLE -- SV_MEETING_DAY SV_MEETING_MONTH_ALPHA SV_MEETING_YEAR</title>
  <link type="text/css" rel="STYLESHEET" href="http://www.w3.org/StyleSheets/base.css">
  <link type="text/css" rel="STYLESHEET" href="http://www.w3.org/StyleSheets/member.css">
  <link type="text/css" rel="STYLESHEET" href="http://www.w3.org/StyleSheets/member-minutes.css">
  <link type="text/css" rel="STYLESHEET" href="http://www.w3.org/2004/02/minutes-style.css">
  <meta content="SV_MEETING_TITLE" name="Title">  
  <meta content="text/html; charset=iso-8859-1" http-equiv="Content-Type">
</head>

<body>
<p><a href="http://www.w3.org/"><img src="http://www.w3.org/Icons/w3c_home" alt="W3C" border="0"
height="48" width="72"></a> 
</p>

SV_DRAFT_WARNING
<h1>SV_MEETING_TITLE<br>
SV_MEETING_DAY SV_MEETING_MONTH_ALPHA SV_MEETING_YEAR</h1>

SV_FORMATTED_AGENDA_LINK

SV_FORMATTED_IRC_URL

<h2><a name="attendees">Attendees</a></h2>

<div class="intro">
<dl>
<dt>Present</dt>
<dd>SV_PRESENT_ATTENDEES</dd>
<dt>Regrets</dt>
<dd>SV_REGRETS</dd>
<dt>Chair</dt>
<dd>SV_MEETING_CHAIR </dd>
<dt>Scribe</dt>
<dd>SV_MEETING_SCRIBE</dd>
</dl>
</div>

<h2>Contents</h2>
<ul>
  <li><a href="#agenda">Topics</a>
	<ol>
	SV_MEETING_AGENDA
	</ol>
  </li>
  <li><a href="#ActionSummary">Summary of Action Items</a></li>
</ul>
<hr>
<div class="meeting">
SV_AGENDA_BODIES
</div>
<h2><a name="ActionSummary">Summary of Action Items</a></h2>
<!-- New Action Items -->
SV_ACTION_ITEMS

[End of minutes] <br>
<hr>

<address>
  Minutes formatted by David Booth's 
  <a href="http://dev.w3.org/cvsweb/~checkout~/2002/scribe/scribedoc.htm">scribe.perl</a> version SCRIBEPERL_VERSION (<a href="http://dev.w3.org/cvsweb/2002/scribe/">CVS log</a>)<br>
  $Date: 2011-05-12 12:01:43 $ 
</address>
<div class="diagnostics">
SV_DIAGNOSTICS
</div>
</body>
</html>
MemberTemplate-EOF
;
return $template;
}

##################################################################
###################### TeamTemplate ############################
##################################################################
sub TeamTemplate
{
my $template = <<'TeamTemplate-EOF'
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" "http://www.w3.org/TR/html4/loose.dtd">
<html lang="en">
<head>
  <title>SV_MEETING_TITLE -- SV_MEETING_DAY SV_MEETING_MONTH_ALPHA SV_MEETING_YEAR</title>
  <link type="text/css" rel="STYLESHEET" href="http://www.w3.org/StyleSheets/base.css">
  <link type="text/css" rel="STYLESHEET" href="http://www.w3.org/StyleSheets/team.css">
  <link type="text/css" rel="STYLESHEET" href="http://www.w3.org/StyleSheets/team-minutes.css">
  <link type="text/css" rel="STYLESHEET" href="http://www.w3.org/2004/02/minutes-style.css">
  <meta content="SV_MEETING_TITLE" name="Title">  
  <meta content="text/html; charset=iso-8859-1" http-equiv="Content-Type">
</head>

<body>
<p><a href="http://www.w3.org/"><img src="http://www.w3.org/Icons/w3c_home" alt="W3C" border="0"
height="48" width="72"></a> 

</p>

SV_DRAFT_WARNING
<h1>SV_MEETING_TITLE<br>
SV_MEETING_DAY SV_MEETING_MONTH_ALPHA SV_MEETING_YEAR</h1>

SV_FORMATTED_AGENDA_LINK

SV_FORMATTED_IRC_URL

<h2><a name="attendees">Attendees</a></h2>

<div class="intro">
<dl>
<dt>Present</dt>
<dd>SV_PRESENT_ATTENDEES</dd>
<dt>Regrets</dt>
<dd>SV_REGRETS</dd>
<dt>Chair</dt>
<dd>SV_MEETING_CHAIR </dd>
<dt>Scribe</dt>
<dd>SV_MEETING_SCRIBE</dd>
</dl>
</div>

<h2>Contents</h2>
<ul>
  <li><a href="#agenda">Topics</a>
	<ol>
	SV_MEETING_AGENDA
	</ol>
  </li>
  <li><a href="#ActionSummary">Summary of Action Items</a></li>
</ul>
<hr>

<div class="meeting">
SV_AGENDA_BODIES
</div>
<h2><a name="ActionSummary">Summary of Action Items</a></h2>
<!-- New Action Items -->
SV_ACTION_ITEMS

[End of minutes] <br>
<hr>

<address>
  Minutes formatted by David Booth's 
  <a href="http://dev.w3.org/cvsweb/~checkout~/2002/scribe/scribedoc.htm">scribe.perl</a> version SCRIBEPERL_VERSION (<a href="http://dev.w3.org/cvsweb/2002/scribe/">CVS log</a>)<br>
  $Date: 2011-05-12 12:01:43 $ 
</address>
<div class="diagnostics">
SV_DIAGNOSTICS
</div>
</body>
</html>
TeamTemplate-EOF
;
return $template;
}

##################################################################
###################### MITTemplate ############################
##################################################################
sub MITTemplate
{
my $template = <<'MITTemplate-EOF'
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" "http://www.w3.org/TR/html4/loose.dtd">
<html lang="en">
<head>
  <title>SV_MEETING_TITLE -- SV_MEETING_DAY SV_MEETING_MONTH_ALPHA
SV_MEETING_YEAR</title>
  <link type="text/css" rel="STYLESHEET"
 href="http://www.w3.org/StyleSheets/base.css">
  <link type="text/css" rel="STYLESHEET"
 href="http://www.w3.org/StyleSheets/team.css">
  <link type="text/css" rel="STYLESHEET"
 href="http://www.w3.org/StyleSheets/team-minutes.css">
  <link type="text/css" rel="STYLESHEET"
 href="http://www.w3.org/2004/02/minutes-style.css">
  <meta content="SV_MEETING_TITLE" name="Title">
  <meta content="text/html; charset=iso-8859-1"
 http-equiv="Content-Type">
</head>
<body>
<p><a href="http://www.w3.org/"><img
 src="http://www.w3.org/Icons/w3c_home" alt="W3C" border="0" height="48"
 width="72"></a> <a href="http://www.w3.org/Team"><img width="48"
 height="48" alt="W3C Team home" border="0"
 src="http://www.w3.org/Icons/WWW/team"></a> | <a
 href="http://www.w3.org/Team/Meeting/MIT-scribes">MIT Meetings</a> | <a
 href="http://lists.w3.org/Archives/Team/w3t-mit/SV_MEETING_YEARSV_MEETING_MONTH_ALPHA/">w3t-mit
archives
</a></p>
SV_DRAFT_WARNING<br style="font-style: italic;">
<span style="font-style: italic;"></span>
<div style="margin-left: 40px;"><span
 style="font-style: italic; font-weight: bold;">To complete these draft
minutes:</span><br style="font-style: italic;">
<ol>
  <li style="font-style: italic;">Grab the "Two minutes reports from
email" at <a href="http://cgi.w3.org/team-bin/mit-2mins">http://cgi.w3.org/team-bin/mit-2mins</a><br>
and insert them near the end of these draft minutes under the "Two
minutes around the table" section.</li>
  <li style="font-style: italic;">Grab the generated table of contents
from those two minutes reports (which appears at the end of the
generated two minutes reports), and move them to the appropriate spot
in the meeting table of contents below.</li>
  <li style="font-style: italic;">Edit these draft minutes overall, and
remove the DRAFT warning, these instructions, the diagnostics at the
end (you did review them first, right?), etc.</li>
  <li style="font-style: italic;">Check the edited minutes back in to
CVS.</li>
  <li style="font-style: italic;">Update the <a
 href="http://www.w3.org/Team/Overview.html#Upcoming">Team page</a><a
 href="http://www.w3.org/Team/Overview.html#Upcoming"> calendar</a> to
include a link to the completed minutes.</li>
  <li style="font-style: italic;">Send email <a
 href="mailto:w3t-mit@w3.org">w3t-mit@w3.org</a> and <a
 href="mailto:w3t@w3.org">w3t@w3.org</a> including:
  <ul style="font-style: italic;">
    <li>a link to the minutes; and</li>
    <li>a text version of the minutes (generated using the <a
 href="http://www.w3.org/,tools">,text comma tool</a>).</li>
  </ul></li>
  <li><span style="font-style: italic;"><span
 style="font-style: italic;">Update the </span><a
 style="font-style: italic;"
 href="http://www.w3.org/Team/Teamtable-MIT.html">MIT scribe list</a><span
 style="font-style: italic;">.</span><br>
    </span></li>
</ol>
</div>
<div style="margin-left: 40px;"><span style="font-style: italic;"></span></div>
<span style="font-style: italic;"><br>
</span>
<h1>SV_MEETING_TITLE<br>
SV_MEETING_DAY SV_MEETING_MONTH_ALPHA SV_MEETING_YEAR</h1>
SV_FORMATTED_AGENDA_LINK
SV_FORMATTED_IRC_URL
<h2><a name="attendees">Attendees</a></h2>
<div class="intro">
<dl>
  <dt>Present</dt>
  <dd>SV_PRESENT_ATTENDEES</dd>
  <dt>Regrets</dt>
  <dd>SV_REGRETS</dd>
  <dt>Chair</dt>
  <dd>SV_MEETING_CHAIR </dd>
  <dt>Scribe</dt>
  <dd>SV_MEETING_SCRIBE</dd>
</dl>
</div>
<h2>Contents</h2>
<ul>
  <li><a href="#agenda">Topics</a>
    <ol>
<!-- Begin Agenda -->
SV_MEETING_AGENDA
<!-- End Agenda -->
    </ol>
  </li>
  <li><a
 href="file:///home/dbooth/w3c/DEV/2002/scribe/mit-template.htm#ActionSummary">Summary
of Action Items</a></li>
  <li><a href="#twoMinutes">Two minutes reports from email</a>
  <ul>
    <li>@@ Insert the table of contents from the result of the
two-minutes generator at <a href="http://cgi.w3.org/team-bin/mit-2mins">http://cgi.w3.org/team-bin/mit-2mins</a>
@@<br>
    </li>
  </ul></li>
</ul>
<hr>
<div class="meeting">
<!-- Begin Bodies -->
SV_AGENDA_BODIES
<!-- End Bodies -->
</div>
<h2><a name="ActionSummary">Summary of Action Items</a></h2>
<!-- Begin Action Items -->
SV_ACTION_ITEMS
<!-- End Action Items -->
<h2><a name="twoMinutes">Two minutes around the table</a></h2>
<p><em>Note to scribe: you can get a start at this section using <a
 href="http://cgi.w3.org/team-bin/mit-2mins">a CGI script</a> that
searches <a href="http://lists.w3.org/Archives/Team/w3t-mit/">the
w3t-mit archive</a> for
2 minute summaries and HTMLizes them.</em></p>
@@ Embed the results of <a href="http://cgi.w3.org/team-bin/mit-2mins">http://cgi.w3.org/team-bin/mit-2mins</a>&nbsp;
here @@ <br>
[End of minutes] <br>
<hr>
<address> Minutes formatted by David Booth's <a
 href="http://dev.w3.org/cvsweb/%7Echeckout%7E/2002/scribe/scribedoc.htm">scribe.perl</a>
version SCRIBEPERL_VERSION (<a
 href="http://dev.w3.org/cvsweb/2002/scribe/">CVS log</a>)<br>
$Date: 2011-05-12 12:01:43 $ </address>
<div class="diagnostics">
SV_DIAGNOSTICS
</div>
</body>
</html>
MITTemplate-EOF
;
return $template;
}

###################################################################
#################### PrintSoftwareLicense #########################
###################################################################
sub PrintSoftwareLicense
{
print <<'End_of_W3C_Software_License_Full_Text'
W3C SOFTWARE NOTICE AND LICENSE
http://www.w3.org/Consortium/Legal/2002/copyright-software-20021231

This work (and included software, documentation such as READMEs, or
other related items) is being provided by the copyright holders under
the following license. By obtaining, using and/or copying this work,
you (the licensee) agree that you have read, understood, and will
comply with the following terms and conditions.

Permission to copy, modify, and distribute this software and its
documentation, with or without modification, for any purpose and
without fee or royalty is hereby granted, provided that you include
the following on ALL copies of the software and documentation or
portions thereof, including modifications:

 1. The full text of this NOTICE in a location viewable to users of
    the redistributed or derivative work.
 2. Any pre-existing intellectual property disclaimers, notices, or
    terms and conditions. If none exist, the [2]W3C Software Short
    Notice should be included (hypertext is preferred, text is
    permitted) within the body of any redistributed or derivative
    code.
 3. Notice of any changes or modifications to the files, including the
    date changes were made. (We recommend you provide URIs to the
    location from which the code is derived.)

   [2] http://www.w3.org/Consortium/Legal/2002/copyright-software-short-notice-20021231.html

THIS SOFTWARE AND DOCUMENTATION IS PROVIDED "AS IS," AND COPYRIGHT
HOLDERS MAKE NO REPRESENTATIONS OR WARRANTIES, EXPRESS OR IMPLIED,
INCLUDING BUT NOT LIMITED TO, WARRANTIES OF MERCHANTABILITY OR FITNESS
FOR ANY PARTICULAR PURPOSE OR THAT THE USE OF THE SOFTWARE OR
DOCUMENTATION WILL NOT INFRINGE ANY THIRD PARTY PATENTS, COPYRIGHTS,
TRADEMARKS OR OTHER RIGHTS.

COPYRIGHT HOLDERS WILL NOT BE LIABLE FOR ANY DIRECT, INDIRECT, SPECIAL
OR CONSEQUENTIAL DAMAGES ARISING OUT OF ANY USE OF THE SOFTWARE OR
DOCUMENTATION.

The name and trademarks of copyright holders may NOT be used in
advertising or publicity pertaining to the software without specific,
written prior permission. Title to copyright in this software and any
associated documentation will at all times remain with copyright
holders.

____________________________________

This formulation of W3C's notice and license became active on December
31 2002. This version removes the copyright ownership notice such that
this license can be used with materials other than those owned by the
W3C, reflects that ERCIM is now a host of the W3C, includes references
to this specific dated version of the license, and removes the
ambiguous grant of "use". Otherwise, this version is the same as the
[3]previous version and is written so as to preserve the [4]Free
Software Foundation's assessment of GPL compatibility and [5]OSI's
certification under the [6]Open Source Definition. Please see our
[7]Copyright FAQ for common questions about using materials from our
site, including specific terms and conditions for packages like
libwww, Amaya, and Jigsaw. Other questions about this notice can be
directed to [8]site-policy@w3.org.

   [3] http://www.w3.org/Consortium/Legal/copyright-software-19980720
   [4] http://www.gnu.org/philosophy/license-list.html#GPLCompatibleLicenses
   [5] http://www.opensource.org/licenses/W3C.php
   [6] http://www.opensource.org/docs/definition.php
   [7] http://www.w3.org/Consortium/Legal/IPR-FAQ
   [8] mailto:site-policy@w3.org

 Joseph Reagle <site-policy@w3.org>

Last revised Id: copyright-software-20021231.html,v 1.11 2004/07/06 16:02:49 slesch Exp

End_of_W3C_Software_License_Full_Text
; 
}

