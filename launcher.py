from appJar import gui
import getpass
import os
from shutil import copyfile
import xml.etree.ElementTree as ET
import datetime
from screeninfo import get_monitors
import json
global app 

def whichSubject(button):
	if button == "Exit":
		print(str(-1))
		exit()
	else:
		app.showSubWindow(button)
		app.hide()
def validateSubject(button):
	global app
	if button == "Validate":
		subject = app.getEntry("Subject")
		age = app.getEntry("Age")
		createPath(subject)
		createMovementJson(subject)
		xml = createXML(subject,age)
		app.stop()
		print(xml)
	elif button == "Cancel":
		app.setEntry("Subject","")
		app.hideSubWindow("New Subject")
		app.show()

def chooseSubject(button):
	global app
	if button == "Choose":
		user = getpass.getuser()
		subject = app.getRadioButton("subjects")
		dataPath = "/home/" + user + "/data"
		subjectPath = dataPath + "/" + subject
		createPath(subject)
		createMovementJson(subject)
		xmlFile = subjectPath + "/mi_stroke_prot.xml" 
		print(xmlFile)
		app.stop()
	elif button == "Back":
		app.hideSubWindow("Existing Subject")
		app.show()

def createPath(subject="dev"):
	user = getpass.getuser()
	dataPath = "/home/" + user + "/data"
	subjectPath = dataPath + "/" + subject
	resourcesPath = subjectPath + "/resources"
	if not os.path.isdir(dataPath):
		os.makedirs(dataPath)
	if not os.path.isdir(subjectPath):
		os.makedirs(subjectPath)
	if not os.path.isdir(resourcesPath):
		os.makedirs(resourcesPath)

def createXML(subject,age):
	user = getpass.getuser()
	dataPath = "/home/" + user + "/data"
	subjectPath = dataPath + "/" + subject
	xmlFile = subjectPath + "/mi_stroke_prot.xml" 
	copyfile("/home/cnbi/.cnbitk/cnbimi/xml/mi_stroke_prot.xml", xmlFile)
	now = datetime.datetime.now()
	tree = ET.parse(xmlFile)
	root = tree.getroot()
	root.find('subject').find('id').text = subject
	root.find('subject').find('age').text = age
	root.find('recording').find('date').text = str(now.day)+str(now.month)+str(now.year)
	tree.write(xmlFile)
	return xmlFile

def createMovementJson(subject):
	user = getpass.getuser()
	dataPath = "/home/" + user + "/data"
	resourcesPath = dataPath + "/" + subject + "/resources"
	authorizedMovementFile = resourcesPath + "/AuthorizedMovements.json"
	flexionFile = resourcesPath + "/flexion.json"
	reachingFile = resourcesPath + "/reaching.json"
	lowStimSingleFile = resourcesPath + "/lowStimSingle.json"
	lowStimDoubleFile = resourcesPath + "/lowStimDouble.json"
	resetFile = resourcesPath + "/reset.json"
	if  not os.path.isfile(authorizedMovementFile) or not os.path.isfile(flexionFile) or not os.path.isfile(reachingFile) or not os.path.isfile(lowStimSingleFile) or not os.path.isfile(lowStimDoubleFile) or not os.path.isfile(resetFile):
		copyfile("/home/cnbi/dev/fesapps/fesjson/resources/AuthorizedMovements.json", authorizedMovementFile)
		copyfile("/home/cnbi/dev/fesapps/fesjson/resources/flexion.json", flexionFile)
		copyfile("/home/cnbi/dev/fesapps/fesjson/resources/reaching.json", reachingFile)
		copyfile("/home/cnbi/dev/fesapps/fesjson/resources/lowStimSingle.json", lowStimSingleFile)
		copyfile("/home/cnbi/dev/fesapps/fesjson/resources/lowStimDouble.json", lowStimDoubleFile)
		copyfile("/home/cnbi/dev/fesapps/fesjson/resources/reset.json", resetFile)
		with open(authorizedMovementFile, 'r') as f:
			data = json.load(f)
			for movement in data["Movements"]:
				if movement["Name"] == "flexion":
					movement["MovementFile"] = flexionFile
				if movement["Name"] == "reaching":
					movement["MovementFile"] = reachingFile
				if movement["Name"] == "lowstimSingle":
					movement["MovementFile"] = lowStimSingleFile
				if movement["Name"] == "lowstimDouble":
					movement["MovementFile"] = lowStimDoubleFile
				if movement["Name"] == "reset":
					movement["MovementFile"] = resetFile
	    	
		with open(authorizedMovementFile, 'w') as f:
			json.dump(data, f, indent=4)
	

user = getpass.getuser()
dataPath = "/home/" + user + "/data"
if not os.path.isdir(dataPath):
	os.makedirs(dataPath)
onlydir = [f for f in os.listdir(dataPath) if os.path.isdir(os.path.join(dataPath, f))]
# app.go
app=gui()
padding = 10;

# this is a pop-up
app.startSubWindow("New Subject")
app.setGuiPadding(padding, padding)
app.addLabelEntry("Subject")
app.getEntry("Subject")
app.addLabelEntry("Age")
app.getEntry("Age")
app.addButtons(["Validate", "Cancel"], validateSubject)
app.setLocation(get_monitors()[0].width/2, get_monitors()[0].height/2)
app.stopSubWindow()

# this is another pop-up
app.startSubWindow("Existing Subject")
for directory in onlydir:
	app.addRadioButton("subjects", directory)
app.addButtons(["Choose", "Back"], chooseSubject)
app.setLocation(get_monitors()[0].width/2, get_monitors()[0].height/2)
app.stopSubWindow()

# these go in the main window
app.addButtons(["New Subject", "Existing Subject", "Exit"], whichSubject)
app.setLocation(get_monitors()[0].width/2, get_monitors()[0].height/2)
app.go()
