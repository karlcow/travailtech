# $Id: Makefile,v 1.3 2008-01-18 18:51:39 swick Exp $

GREP=/bin/grep
PERL=/usr/bin/perl
ECHO=/bin/echo

tests: scribe.pl xssVulnerabilityTests

xssVulnerabilityTests: testTemplate.html xssVulnerabilityTest1 xssVulnerabilityTest2 xssVulnerabilityTest3 xssVulnerabilityTest4 xssVulnerabilityTest5

xssVulnerabilityTest1: xssVulnerabilityTest1.txt
	@if ($(PERL) scribe.pl xssVulnerabilityTest1.txt -embedDiagnostics -template testTemplate.html 2> /dev/null | $(GREP) -q -c '<img'); then $(ECHO) 'FAILURE: xss vulnerability test 1 failed'; else $(ECHO) 'xss vulnerability test 1 passed'; fi

xssVulnerabilityTest2: xssVulnerabilityTest2.txt
	@if ($(PERL) scribe.pl xssVulnerabilityTest2.txt -embedDiagnostics -template testTemplate.html 2> /dev/null | $(GREP) -q -c '<img'); then $(ECHO) 'FAILURE: xss vulnerability test 2 failed'; else $(ECHO) 'xss vulnerability test 2 passed'; fi

xssVulnerabilityTest3: xssVulnerabilityTest3.txt
	@if ($(PERL) scribe.pl xssVulnerabilityTest3.txt -embedDiagnostics -template testTemplate.html 2> /dev/null | $(GREP) -q -c '<img'); then $(ECHO) 'FAILURE: xss vulnerability test 3 failed'; else $(ECHO) 'xss vulnerability test 3 passed'; fi

xssVulnerabilityTest4: xssVulnerabilityTest4.txt
	@if ($(PERL) scribe.pl xssVulnerabilityTest4.txt -embedDiagnostics -template testTemplate.html 2> /dev/null | $(GREP) -q -c '<img'); then $(ECHO) 'FAILURE: xss vulnerability test 4 failed'; else $(ECHO) 'xss vulnerability test 4 passed'; fi

xssVulnerabilityTest5: xssVulnerabilityTest5.txt
	@if ($(PERL) scribe.pl xssVulnerabilityTest5.txt -embedDiagnostics -template testTemplate.html 2> /dev/null | $(GREP) -q -c '<img'); then $(ECHO) 'FAILURE: xss vulnerability test 5 failed'; else $(ECHO) 'xss vulnerability test 5 passed'; fi
