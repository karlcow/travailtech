This directory contains regression test cases (test-cases/*) for scribe.perl,
and a regression test harness: regtest.perl.   See regtest.perl
for instructions.  Helper scripts:

	okdiffs.perl: Used to ignore output differences that do not indicate
		a problem.

	acceptemptydiffs: This was for accepting the new versions
		if there were no differences.  I don't remember if this 
		is useful any more.  Maybe the -a option to regtest.perl 
		makes this obsolete?  Or the -n option?  Not sure.

