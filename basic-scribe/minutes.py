#!/usr/bin/env python
# encoding: utf-8
"""
Minutes.py

Created by Olivier Thereaux on 2010-03-02. 
Distributed under the terms of the Artistic License 2.0
http://opensource.org/licenses/artistic-license-2.0.php
"""

import sys
import os
import unittest
import datetime
import cgi
import cgitb
import re
import urllib
from time import strftime
cgitb.enable()


class Minutes:
    def __init__(self, meetingname= None, meetingdate=None, meetingparticipants=None, meetingchair=None, meetingscribe= None, meetingnotes=None):
        self.meetingname= meetingname
        self.meetingdate = meetingdate
        self.meetingparticipants = meetingparticipants
        self.meetingnotes = meetingnotes
        if self.meetingnotes == None:
            self.meetingnotes = ""
        self.meetingchair = meetingchair
        self.meetingscribe = meetingscribe
        self.meetingactionitems = list()
        self.meetingagenda = list()
        self.minutestemplate = u"""<p class="dateDeposee">le %(MEETINGDATE)s</p>
                <div class="intro">
                    <div class="introContact">
                        <ul>
                            <li>Scribe : %(MEETINGSCRIBE)s</li>
                            <li>Chair : %(MEETINGCHAIR)s</li>
                            <li>Présents : %(MEETINGPARTICIPANTS)s</li>
                        </ul>
                    </div>
                    <div class="introWhat">
                        <ul>
                        <li><a href="#agenda">Agenda</a>
                        <ol>
                        %(MEETINGAGENDA)s
                        </ol>
                        </li>
                        <li><a href="#ActionSummary">Sommaire des actions</a></li>
                        </ul>
                    </div>
                </div><!-- intro end -->
                <hr class="endIntro" />
                <div class="meeting">
                    <h2>Notes de Réunion</h2>
        %(MEETINGNOTES)s
                </div>
                <h2 id="ActionSummary">Sommaire des Actions et Résolutions</h2>
        %(MEETINGACTIONS)s
        <!-- @@ add footer ? @@ --> 
        """
        
        return None
    
    def __unicode__(self):
        """output the meeting name and date """
        return u"%s, %s" % (self.meetingname, self.meetingdate)

    def __str__(self):
        """output the meeting name and date """
        return u"%s, %s" % (self.meetingname, self.meetingdate)

    def preparse(self):
        """read the meeting notes and parse out the action items, agenda etc"""
        self.actionitems
        pass

    def ashtml(self):
        """output minutes as HTML"""
        actions_as_html = u""
        agenda_as_html = u""
        notes_as_html = u""
        
        for action in self.meetingactionitems:
            actions_as_html = "".join ([actions_as_html, "<li><strong>", action["type"].upper(), "</strong>: ", action["text"], "</li>"])
        if len(actions_as_html):
            actions_as_html = "".join(["<ul>", actions_as_html, "</ul>"])
        for agenda in self.meetingagenda:
            agenda_as_html = "".join ([agenda_as_html, "<li><a href='#", urllib.quote(agenda.encode("ascii", "ignore")), "'>", agenda, "</a></li>"])
        if len(agenda_as_html):
            agenda_as_html = "".join(["<ul>", agenda_as_html, "</ul>"])
        notes_author_regex = re.compile(r'((.+): (.+))')
        agendaregex = re.compile(r'(Sujet: (.*))')
        actionsregex = re.compile(r'(ACTION: (.*))')
        resolutionsregex = re.compile(r'(RESOLUTION: (.*))')
        
        for notesline in self.meetingnotes.splitlines():
            authormatch = notes_author_regex.match(notesline)
            agendamatch = agendaregex.match(notesline)
            actionmatch = actionsregex.match(notesline)
            resolutionmatch = resolutionsregex.match(notesline)
            if agendamatch:
                notes_as_html = "".join([notes_as_html, "<h3 id='", urllib.quote(agendamatch.group(2).encode("ascii", "ignore")),"'>", agendamatch.group(2), """</h3>
"""])
            elif actionmatch:
                notes_as_html = "".join([notes_as_html, "<p><strong>ACTION</strong>: ", actionmatch.group(2), """</p>
"""])
            elif resolutionmatch:
                notes_as_html = "".join([notes_as_html, "<p><strong>RESOLUTION</strong>: ", resolutionmatch.group(2), """</p>
"""])
            elif authormatch:
                notes_as_html = "".join([notes_as_html, "<p class='phone'><cite>", authormatch.group(2), "</cite>: ", authormatch.group(3), """</p>
"""])
            else:
                notes_as_html = "".join([notes_as_html, "<p class='phone'>", notesline, "</p>\n"])
        notes_as_html = re.sub("</p>\n<p class='phone'>( +)\.\.\.", "<br />", notes_as_html)
        notes_as_html = "<p>"+notes_as_html+"</p>"
        htmlready = self.minutestemplate % {"MEETINGAGENDA": agenda_as_html, 
        "MEETINGACTIONS": actions_as_html, 
        "MEETINGNOTES": notes_as_html, 
        "MEETINGPARTICIPANTS": self.meetingparticipants, 
        "MEETINGCHAIR": self.meetingchair, 
        "MEETINGSCRIBE": self.meetingscribe, 
        "MEETINGDATE": self.meetingdate, 
        "MEETINGNAME": self.meetingname, }
        return htmlready

    def parse_agenda(self):
        """parse the meeting notes and retrieve the topics"""
        agendaregex = re.compile(r'((Sujet|Topic|Agenda): (.*))')
        for notesline in self.meetingnotes.splitlines():
            agendamatch = agendaregex.match(notesline)
            if (agendamatch):
                self.meetingagenda.append(agendamatch.group(3))

    def parse_action_items(self):
        """parse the meeting notes and retrieve the action items"""
        
        actionsregex = re.compile(r'(ACTION: (.*))')
        resolutionsregex = re.compile(r'(RESOLUTION: (.*))')
        for notesline in self.meetingnotes.splitlines():
            actionmatch = actionsregex.match(notesline)
            resolutionmatch = resolutionsregex.match(notesline)
            if (actionmatch):
                self.meetingactionitems.append({"type": "action", "text": actionmatch.group(2)})
            if (resolutionmatch):
                self.meetingactionitems.append({"type": "resolution", "text": resolutionmatch.group(2)})
        return None

class MinutesTests(unittest.TestCase):
    def setUp(self):
        pass

    def test_ashtml(self):
        meetingminutes = Minutes()
        html_minutes = meetingminutes.ashtml()
        self.maxDiff = None
        self.assertEquals(html_minutes, meetingminutes.minutestemplate % {"MEETINGAGENDA": "", 
        "MEETINGACTIONS": "", 
        "MEETINGNOTES": "<p></p>", 
        "MEETINGPARTICIPANTS": "None", 
        "MEETINGCHAIR": "None", 
        "MEETINGSCRIBE": "None", 
        "MEETINGDATE": "None", 
        "MEETINGNAME": "None", }
        )
    
    def test_parse_agenda(self):
        meetingminutes = Minutes()
        meetingminutes.meetingnotes= u"""Topic: La fin du monde
AB: je réponds avec une phrase particulièrement longue
        ... qui continue sur plusieurs lignes
ACTION: Richard va envoyer les nouveaux formulaires pour les TPS reports, d'ici le 24 mars
RESOLUTION: tout le monde doit commencer à utiliser les nouveaux formulaires a partir du 1er avril
"""
        meetingminutes.parse_agenda()
        self.assertEquals(meetingminutes.meetingagenda, ["La fin du monde"])
    
    def test_parse_action_items(self):
        meetingminutes = Minutes()
        meetingminutes.meetingnotes= u"""OT: une phrase de texte assez courte
AB: je réponds avec une phrase particulièrement longue
... qui continue sur plusieurs lignes
ACTION: Richard va envoyer les nouveaux formulaires pour les TPS reports, d'ici le 24 mars
RESOLUTION: tout le monde doit commencer à utiliser les nouveaux formulaires a partir du 1er avril
"""
        meetingminutes.parse_action_items()
        self.assertEquals(meetingminutes.meetingactionitems, [{"type": "action", "text": u"Richard va envoyer les nouveaux formulaires pour les TPS reports, d'ici le 24 mars"}, {"type": "resolution", "text": u"tout le monde doit commencer à utiliser les nouveaux formulaires a partir du 1er avril"}])

if __name__ == '__main__':
    form = cgi.FieldStorage()
    if form.has_key("meetingnotes"):
        if form.has_key("meetingname"):
            meetingname=cgi.escape(form["meetingname"].value.decode("utf-8"))
        else:
            meetingname= "Reunion"
        if form.has_key("meetingtopic"):
            meetingtopic=cgi.escape(re.sub(" ", "", form["meetingtopic"].value.decode("utf-8")))
        else:
            meetingtopic= "".join(map(str.capitalize, meetingname.encode("ascii", "ignore").split()))
            meetingtopic= "".join([meetingtopic, strftime("%Y%m%d")])
        meetingdate=cgi.escape(form["meetingdate"].value.decode("utf-8"))
        meetingparticipants=cgi.escape(form["meetingparticipants"].value.decode("utf-8"))
        meetingnotes=cgi.escape(form["meetingnotes"].value.decode("utf-8"))
        meetingchair=cgi.escape(form["meetingchair"].value.decode("utf-8"))
        meetingscribe=cgi.escape(form["meetingscribe"].value.decode("utf-8"))
        meetingminutes = Minutes(meetingname=meetingname, meetingdate=meetingdate, meetingparticipants = meetingparticipants, meetingchair=meetingchair, meetingscribe= meetingscribe, meetingnotes=meetingnotes)
        meetingminutes.parse_agenda()
        meetingminutes.parse_action_items()
        htmlminutes = meetingminutes.ashtml()
        print 'Content-type: text/html; charset=utf-8\n'
        report =  u"""<!DOCTYPE html>
<html>
	<head>
	    <title>Votre Compte Rendu est prêt!</title>
        <meta charset="utf-8"/>
        <style type="text/css" media="all">
        <style type="text/css" media="screen, print">
            html{ font-size: 18px; line-height: 170%;}
            body { background:#fff; color: #333; font-family: 'Gill Sans', Arial, Helvetica; }
            h2 { font-size: 1.2em; margin-top: 1em; padding-bottom: 1em; border-top: 1px solid #ddd; padding-top: 1.5em;  text-align: center; width: 100%;}
            h3 { font-size: 1.3em; margin-top: 1em; font-weight: 100; padding-top: .5em;}
            h1 { text-shadow: 0px 1px 0px rgba(255, 255, 255, 0.8); font-weight: 100; margin: 1em 0; text-align: center;}
            p { margin: 1em;}
            article {display: block; padding: 0 3em; padding-bottom: 3em; margin-bottom: 0; margin-left: auto; margin-right: auto; max-width: 40em;}
            ul li, ol li {padding: .5em 0; padding-bottom: 1em;}
            ol li {list-style-type: decimal; }
            ol li li {list-style-type: lower-alpha; padding-bottom: .3em;}
            ol li li li {list-style-type: circle;}
            a, a:link, a:visited { color: #900;}
            a:active, a:hover { color: #f33; text-decoration: underline; }
            strong.resolution{color:red;}
            .phone{clear:left;margin:0.2em 1em 0 1em;padding:5px;}
            .phone cite{width:5em;padding:3px;margin:0 3px 0 0;font-weight:bold;}
            .irc{clear:left;margin:0 1em 0 3em;padding:5px;background-color:#eee;}
            .irc cite{width:5em;padding:3px;font-weight:bold;}
            .meeting{padding:0.5em;}
            .meeting h3{margin:2em 0 1em 0.2em;}
            .actionitem{margin:5px 0;}
            .actionitem strong.statut{font-variant:small-caps;font-family:helvetica,sans-serif;font-size:90%%;padding:2px;}
            strong.pending{background-color:#FC3;border-right:1px solid #C90;border-bottom:1px solid #C90;}
            strong.new{background-color:#CF9;border-right:1px solid #9C3;border-bottom:1px solid #9C3;}
            strong.done{background-color:#ddd;border-right:1px solid #eee;border-bottom:1px solid #eee;}
            #generatedcontent {border: 1px solid #ccc; margin-left: 10%%; margin-right: 10%%; margin-bottom: 1em; padding: 1em; }
            .sendminutes {font-size: larger; color: #363; }
        </style>
        <link type="text/css" rel="STYLESHEET" href="http://www.w3.org/2004/02/minutes-style.css">
	</head>
    <body>
        <h1>Votre compte-rendu est prêt!</h1><form action='http://example.com/wiki/minutes/new' method='post'accept-charset="utf-8">
        <textarea name='text' style="display:none">%s</textarea>
        <p>Vérifiez le texte généré ci-dessous.</p>
        <p><input type="submit" class="sendminutes" value="Editer et sauvegarder le résultat" />
         ou <em style="font-size: larger">Retourner à la page précédente</em> pour effectuer des corrections.</p>
         <hr />
         <h2>Votre compte-rendu généré</h2>
         <div id="generatedcontent">%s</div>
         <p style="text-align:center"><input type="submit" class="sendminutes" value="OK, envoyer ce rapport" /></p>
         </form>
         </body></html> 
        """ % (cgi.escape(htmlminutes.encode('ascii', 'xmlcharrefreplace')), meetingtopic, meetingtopic, htmlminutes)
        print report.encode("utf-8")
    else:
        unittest.main()