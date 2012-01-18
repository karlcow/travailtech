#! /usr/bin/perl -w

my $disable = 1;	# Disable this filter?  (I.e., pass through everything)

# This filter is used by regtest.perl.  Read that first.
#
# Filter out diffs that are ignorable.   I.e., delete any differences
# that can be ignored, leaving only those differences that matter.
# This is *only* supposed to be used when testing a new feature
# or bug fix to scribe.perl that intentionally changes the output
# of scribe.perl.  It allows you to more easily find other differences
# that you did *not* intend.  There is one minor glitch in this
# algorithm though: the remaining differences that are reported
# have been modified if $ignoreNumberDifferences and/or
# $ignoreTrailingBlanks is set.
#
# Stdin: diffs noticed by regtest.perl.  
# Stdout: Any differences that are NOT ignorable.
#
# To use okdiffs.perl to filter out ignorable differences: 
#	1. Before starting a new enhancement/bugfix to scribe.perl, 
#	you may need to (probably should)
#	clear out the previously used &IgnorableLiteralN
#	and &IgnorablePatternN functions
#	below, since they may no longer apply.
#
#	2. Then set $disable = 0 and do steps 3 & 4 for
#	each difference that can be ignored.
#
# 	3. Define an &IgnorableLiteralN function and/or an
# 	&IgnorablePatternN function at the end of this file.
#	Each function should return either a literal or a
#	pattern (depending on which kind of function you defined)
#	for diff text that can be ignored.  
#
# 	4. Add a call to it in the list of @ignorableLiterals 
# 	or @ignorablePatterns below, as appropriate.
#
#	5. Once a feature/bugfix has been fully accepted using
#	regtest.perl, you should set $disable = 1 to
#	disable this filter until you next need it.  (If this
#	filter is disabled, it will not ignore any differences.
#	Thus, all differences will be considered significant.)

my $ignoreNumberDifferences = 1;	# Ignore differences in numbers?
my $ignoreTrailingBlanks = 0;		# Ignore trailing blanks?
my $ignoreMonthDifferences = 1;		# Ignore diffs in months?

my $all = join("",<>);
my @ignorableLiterals = (
	# &IgnorableLiteral1(), 
	# &IgnorableLiteral2(), 
	# &IgnorableLiteral3(),
	# &IgnorableLiteral4(),
	# &IgnorableLiteral5(),
	# &IgnorableLiteral6(),
	# &IgnorableLiteral7(),
	# &IgnorableLiteral8(),
	#### Add your new "&IgnorableLiteralN()," calls here.
	);
my @ignorablePatterns = (
	# &IgnorablePattern1(), 
	# &IgnorablePattern2(), 
	# &IgnorablePattern3(), 
	#### Add your new "&IgnorablePatternN()," calls here.
	);

if ($disable)
	{
	@ignorableLiterals = ();
	@ignorablePatterns = ();
	}

my $nbspToSpace = 0;		# Convert &nbsp; to space?
if ($nbspToSpace)
	{
	while ($all =~ s/(\n\>(.*))\&nbsp\;/$1 /g) {}
	}

my $tabToSpace = 0;		# Convert tabs to space?
if ($nbspToSpace)
	{
	while ($all =~ s/(\n\<(.*))\t/$1        /g) {}
	}

# Apply the same transformations to @ignorableLiterals and $all
my @strings = ($all, @ignorableLiterals);
for (my $i=0; $i<@strings; $i++)
	{
	$strings[$i] =~ s/\d+/0/g if ($ignoreNumberDifferences);
	$strings[$i] =~ s/[ \t]+\n/\n/g if ($ignoreTrailingBlanks);
	my $monthsPattern = 'Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec';
	$strings[$i] =~ s/\b($monthsPattern)\b/Jan/g if ($ignoreMonthDifferences);
	}
($all, @ignorableLiterals) = @strings;

# Delete anything that  was not really a change (after above transforms)
$all = &DeleteUnchanged($all);

# Delete any other ignorable literals.
foreach my $lit (@ignorableLiterals)
	{
	my $qi = quotemeta($lit);
	$all =~ s/$qi//g;
	}

foreach my $ignorablePattern (@ignorablePatterns)
	{
	# warn "ignorablePattern: \n$ignorablePattern\n";
	# warn "all: \n$all\n";
	$all =~ s/$ignorablePattern//mg;
	}

# Whatever differences remain should not be ignored.
print $all;
exit 0;

###############################################
# Delete unchanged parts: part that show as changes
# but (after transformation such as converting numbers to 0)
# are not actually changes.
# Example:
#	0c0
#	<   <title>MIT Site meeting -- 0 Jan 0</title>
#	---
#	>   <title>MIT Site meeting -- 0 Jan 0</title>
sub DeleteUnchanged
{
@_ == 1 || die;
my ($all) = @_;
if ($all =~ m/^\d+(\,\d+)?c\d+(\,\d+)?\n((\<.*\n)+)\-\-\-\n((\>.*\n)+)/m)
	{
	my $pre = $`;
	my $old = $3;
	my $new = $5;
	my $post = $';
	my $match = $&;
	$new =~ s/(^|\n)\>/$1\</g;
	# warn "Found possible unchanged.  Old:\n$old" . "New:\n$new\n";
	# die;
	# Turn off deep recursion warnings
	# per http://www.codecomments.com/archive235-2004-10-304141.html
	no warnings 'recursion';
	return(&DeleteUnchanged($pre) . &DeleteUnchanged($post)) if ($old eq $new);
	return(&DeleteUnchanged($pre) . $match . &DeleteUnchanged($post));
	}
return($all);
}

###############################################
sub IgnorablePattern1
{
my $sample = <<'EOSAMPLE'
158c158
< &lt;<cite>RalphS</cite>&gt; [-&gt; <a href="http://lists.w3.org/Archives/Team/w3t-mit/2005Feb/0093.html">http://lists.w3.org/Archives/Team/w3t-mit/2005Feb/0093.html</a> Matthieu's two minutes]
---
> &lt;<cite>RalphS</cite>&gt; [<a href="http://lists.w3.org/Archives/Team/w3t-mit/2005Feb/0093.html">Matthieu's two minutes</a>]
EOSAMPLE
;
$sample = $sample;
my $up = quotemeta('http://lists.w3.org/Archives/Team/w3t-mit/2005Feb/0093.html');
$sample =~ s/$up/URL/g;
my $sp = quotemeta("Matthieu's two minutes");
$sample =~ s/$sp/TEXT/g;
my $pattern = quotemeta($sample);
$pattern =~ s/\d+/\\d+/g;
$pattern =~ s/RalphS/\\w+/g;
$pattern =~ s/URL/http\\:\[\^\\\"\]+/g;
$pattern =~ s/TEXT/\[\^\\\]\]*/g;
# warn "pattern: \n$pattern\n";
# die;
return($pattern);
}

###############################################
sub IgnorablePattern2
{
my $sample = <<'EOSAMPLE'
0c0
< -&gt; <a href="http://lists.w0.org/Archives/Team/w0t-mit/0Jan/0.html">http://lists.w0.org/Archives/Team/w0t-mit/0Jan/0.html</a> Philippe's two minutes
---
> <a href="http://lists.w0.org/Archives/Team/w0t-mit/0Jan/0.html">Philippe's two minutes</a>
EOSAMPLE
;
$sample = $sample;
my $up = quotemeta('http://lists.w0.org/Archives/Team/w0t-mit/0Jan/0.html');
$sample =~ s/$up/URL/g;
my $sp = quotemeta("Philippe's two minutes");
$sample =~ s/$sp/TEXT/g;
my $pattern = quotemeta($sample);
$pattern =~ s/\d+/\\d+/g;
$pattern =~ s/RalphS/\\w+/g;
$pattern =~ s/URL/http\\:\[\^\\\"\]+/g;
$pattern =~ s/TEXT/\[\^\\\]\]*/g;
# warn "pattern: \n$pattern\n";
# die;
return($pattern);
}

###############################################
sub IgnorablePattern3
{
my $sample = <<'EOSAMPLE'
0c0
< [-&gt; <a href="http://lists.w0.org/Archives/Team/w0t-mit/0Jan/0.html">http://lists.w0.org/Archives/Team/w0t-mit/0Jan/0.html</a> Philippe's two minutes]
---
> [<a href="http://lists.w0.org/Archives/Team/w0t-mit/0Jan/0.html">Philippe's two minutes</a>]
EOSAMPLE
;
$sample = $sample;
my $up = quotemeta('http://lists.w0.org/Archives/Team/w0t-mit/0Jan/0.html');
$sample =~ s/$up/URL/g;
my $sp = quotemeta("Philippe's two minutes");
$sample =~ s/$sp/TEXT/g;
my $pattern = quotemeta($sample);
$pattern =~ s/\d+/\\d+/g;
$pattern =~ s/RalphS/\\w+/g;
$pattern =~ s/URL/http\\:\[\^\\\"\]+/g;
$pattern =~ s/TEXT/\[\^\\\]\]*/g;
# warn "pattern: \n$pattern\n";
# die;
return($pattern);
}

###############################################
sub IgnorableLiteral1
{
my $ignorable = <<'EOF'
119,123d118
<
< </p>
<
< <p class='phone'>
<
EOF
;
return($ignorable);
}

###############################################
sub IgnorableLiteral2
{
my $ignorable = <<'EOF'
61,67d60
< <p class='phone'>
<
<
< </p>
<
< <p class='phone'>
<
72,73d64
< </p>
<
386a378
>
452a445,452
> WARNING: No "Topic: ..." lines found!
> Resulting HTML may have an empty (invalid) &lt;ol&gt;...&lt;/ol&gt;.
>
> Explanation: "Topic: ..." lines are used to indicate the start of
> new discussion topics or agenda items, such as:
> &lt;dbooth&gt; Topic: Review of Amy's report
>
>
EOF
;
return($ignorable);
}

###############################################
sub IgnorableLiteral3
{
my $ignorable = <<'EOF'
53,59d52
< <p class='phone'>
<
<
< </p>
<
< <p class='phone'>
<
64,65d56
< </p>
<
1045a1037
>
EOF
;
return($ignorable);
}

###############################################
sub IgnorableLiteral4
{
my $ignorable = <<'EOF'
89,94d88
<
<
< </p>
<
< <p class='phone'>
<
3048a3043
>
3116a3112,3119
> WARNING: No "Topic: ..." lines found!
> Resulting HTML may have an empty (invalid) &lt;ol&gt;...&lt;/ol&gt;.
>
> Explanation: "Topic: ..." lines are used to indicate the start of
> new discussion topics or agenda items, such as:
> &lt;dbooth&gt; Topic: Review of Amy's report
>
>
EOF
;
return($ignorable);
}

###############################################
sub IgnorableLiteral5
{
my $ignorable = <<'EOF'
54,59d53
<
<
< </p>
<
< <p class='phone'>
<
111a106
>
EOF
;
return($ignorable);
}

###############################################
sub IgnorableLiteral6
{
my $ignorable = <<'EOF'
53,59d52
< <p class='phone'>
<
<
< </p>
<
< <p class='phone'>
<
64,65d56
< </p>
<
1045a1037
>
EOF
;
return($ignorable);
}

###############################################
sub IgnorableLiteral7
{
my $ignorable = <<'EOF'
89,94d88
<
<
< </p>
<
< <p class='phone'>
<
3048a3043
>
3116a3112,3119
> WARNING: No "Topic: ..." lines found!
> Resulting HTML may have an empty (invalid) &lt;ol&gt;...&lt;/ol&gt;.
>
> Explanation: "Topic: ..." lines are used to indicate the start of
> new discussion topics or agenda items, such as:
> &lt;dbooth&gt; Topic: Review of Amy's report
>
>
EOF
;
return($ignorable);
}

###############################################
sub IgnorableLiteral8
{
my $ignorable = <<'EOF'
0,0d0
< <p class='phone'>
<
<
< </p>
<
< <p class='phone'>
<
0,0d0
< </p>
<
EOF
;
return($ignorable);
}

