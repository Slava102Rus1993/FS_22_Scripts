CreditsScreen = {
	TITLE = 0,
	TEXT = 1,
	SEPARATOR = 2,
	DISCLAIMER = 3,
	CONTROLS = {
		CREDITS_TITLE_ELEMENT = "creditsTitleElement",
		CREDITS_TEXT_ELEMENT = "creditsTextElement",
		LOGO = "logo",
		CREDITS_PLACEHOLDER = "creditsPlaceholder",
		CREDITS_DISCLAIMER_ELEMENT = "creditsDisclaimerElement",
		CREDITS_BOX = "creditsVisibilityBox"
	},
	LIST_TEMPLATE_ELEMENT_NAME = {}
}
local CreditsScreen_mt = Class(CreditsScreen, ScreenElement)

function CreditsScreen.new(target, custom_mt)
	local self = ScreenElement.new(target, custom_mt or CreditsScreen_mt)

	self:registerControls(CreditsScreen.CONTROLS)

	self.returnScreenName = "MainScreen"

	return self
end

function CreditsScreen:onCreate(element)
	self.creditsTitleElement:unlinkElement()
	self.creditsTextElement:unlinkElement()
	self.creditsDisclaimerElement:unlinkElement()
	self:loadCredits()

	self.creditsStartY = self.creditsPlaceholder.absPosition[2]
end

function CreditsScreen:onOpen()
	CreditsScreen:superClass().onOpen(self)

	for _, item in pairs(self.creditsElements) do
		item:setAlpha(0)
	end

	self.nextFadeInCreditsItemId = 1
	self.nextFadeOutCreditsItemId = 1

	self.creditsPlaceholder:setAbsolutePosition(self.creditsPlaceholder.absPosition[1], self.creditsStartY)
end

function CreditsScreen:delete()
	self.creditsTitleElement:delete()
	self.creditsTextElement:delete()
	self.creditsDisclaimerElement:delete()
	CreditsScreen:superClass().delete(self)
end

function CreditsScreen:update(dt)
	CreditsScreen:superClass().update(self, dt)
	self.creditsPlaceholder:setAbsolutePosition(self.creditsPlaceholder.absPosition[1], self.creditsPlaceholder.absPosition[2] + 7e-05 * dt)

	if self.nextFadeInCreditsItemId <= #self.creditsElements then
		local y = self.creditsElements[self.nextFadeInCreditsItemId].absPosition[2]

		if self.creditsVisibilityBox.absPosition[2] < y then
			self.creditsElements[self.nextFadeInCreditsItemId]:fadeIn(1.2)

			self.nextFadeInCreditsItemId = self.nextFadeInCreditsItemId + 1
		end
	end

	if self.nextFadeOutCreditsItemId <= #self.creditsElements then
		local y = self.creditsElements[self.nextFadeOutCreditsItemId].absPosition[2]

		if y > self.creditsVisibilityBox.absPosition[2] + self.creditsVisibilityBox.size[2] * 0.8 then
			self.creditsElements[self.nextFadeOutCreditsItemId]:fadeOut(4)

			self.nextFadeOutCreditsItemId = self.nextFadeOutCreditsItemId + 1
		end
	else
		self:onClickBack()
	end
end

function CreditsScreen:loadCredits()
	local creditsTexts = {}

	table.insert(creditsTexts, {
		c = "Developed by",
		t = CreditsScreen.TITLE
	})
	table.insert(creditsTexts, {
		c = "GIANTS Software GmbH",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		t = CreditsScreen.SEPARATOR
	})
	table.insert(creditsTexts, {
		c = "Executive Producer",
		t = CreditsScreen.TITLE
	})
	table.insert(creditsTexts, {
		c = "Christian Ammann",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		t = CreditsScreen.SEPARATOR
	})
	table.insert(creditsTexts, {
		c = "Chief Technical Officer",
		t = CreditsScreen.TITLE
	})
	table.insert(creditsTexts, {
		c = "Stefan Geiger",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		t = CreditsScreen.SEPARATOR
	})
	table.insert(creditsTexts, {
		c = "Creative Director",
		t = CreditsScreen.TITLE
	})
	table.insert(creditsTexts, {
		c = "Thomas Frey",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		t = CreditsScreen.SEPARATOR
	})
	table.insert(creditsTexts, {
		c = "Lead Level Designer",
		t = CreditsScreen.TITLE
	})
	table.insert(creditsTexts, {
		c = "Renzo Thönen",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		t = CreditsScreen.SEPARATOR
	})
	table.insert(creditsTexts, {
		c = "Lead Programmer",
		t = CreditsScreen.TITLE
	})
	table.insert(creditsTexts, {
		c = "Thomas Brunner",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		t = CreditsScreen.SEPARATOR
	})
	table.insert(creditsTexts, {
		c = "Lead Gameplay Programmer",
		t = CreditsScreen.TITLE
	})
	table.insert(creditsTexts, {
		c = "Manuel Leithner",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		t = CreditsScreen.SEPARATOR
	})
	table.insert(creditsTexts, {
		c = "Lead Artist",
		t = CreditsScreen.TITLE
	})
	table.insert(creditsTexts, {
		c = "Marc Schwegler",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		t = CreditsScreen.SEPARATOR
	})
	table.insert(creditsTexts, {
		c = "Studio Manager",
		t = CreditsScreen.TITLE
	})
	table.insert(creditsTexts, {
		c = "Lukáš Kuře",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		t = CreditsScreen.SEPARATOR
	})

	if Platform.isPlaystation then
		table.insert(creditsTexts, {
			c = "Senior PlayStation®4/5 Programmer",
			t = CreditsScreen.TITLE
		})
		table.insert(creditsTexts, {
			c = "Eddie Edwards",
			t = CreditsScreen.TEXT
		})
		table.insert(creditsTexts, {
			t = CreditsScreen.SEPARATOR
		})
		table.insert(creditsTexts, {
			c = "Senior Programmer",
			t = CreditsScreen.TITLE
		})
	else
		table.insert(creditsTexts, {
			c = "Senior Programmer",
			t = CreditsScreen.TITLE
		})
		table.insert(creditsTexts, {
			c = "Eddie Edwards",
			t = CreditsScreen.TEXT
		})
	end

	table.insert(creditsTexts, {
		c = "Olivier Fouré",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		c = "Samo Jordan",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		t = CreditsScreen.SEPARATOR
	})
	table.insert(creditsTexts, {
		c = "Programmers",
		t = CreditsScreen.TITLE
	})
	table.insert(creditsTexts, {
		c = "Bao-Anh Dang-Vu",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		c = "Bojan Kerec",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		c = "Gino van den Bergen",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		c = "Jan Dellsperger",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		c = "Jos Kuijpers",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		c = "Laura Jenkins",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		c = "Lukas Nussbaumer",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		c = "Marius Hofmann",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		c = "Nicolas Wrobel",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		c = "Stefan Maurus",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		c = "Travis Gesslein",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		t = CreditsScreen.SEPARATOR
	})
	table.insert(creditsTexts, {
		c = "Lead Vehicle Artist",
		t = CreditsScreen.TITLE
	})
	table.insert(creditsTexts, {
		c = "Tomáš Dostál",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		t = CreditsScreen.SEPARATOR
	})
	table.insert(creditsTexts, {
		c = "Lead Character Artists",
		t = CreditsScreen.TITLE
	})
	table.insert(creditsTexts, {
		c = "Mike Wasilewski",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		c = "Roman Pelypenko",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		t = CreditsScreen.SEPARATOR
	})
	table.insert(creditsTexts, {
		c = "Technical Artists",
		t = CreditsScreen.TITLE
	})
	table.insert(creditsTexts, {
		c = "Evgeniy Zaitsev",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		c = "Horia Serban",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		c = "Marta Stolarz",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		t = CreditsScreen.SEPARATOR
	})
	table.insert(creditsTexts, {
		c = "Artists",
		t = CreditsScreen.TITLE
	})
	table.insert(creditsTexts, {
		c = "Angelo Panciotto",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		c = "Dalibor Werner",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		c = "Filip Dufka",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		c = "Florian Busse",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		c = "Gabriel Hubli",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		c = "Irina Pedash",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		c = "Ivan Stanchev",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		c = "Jakub Haltmar",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		c = "Jakub Havel",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		c = "Jakub Valehrach",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		c = "Jan Dobrovolný",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		c = "Jan Egon Preiss",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		c = "Ján Ohajský",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		c = "Jiří Zábranský",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		c = "Jonathan Goodman",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		c = "Kamil Tesař",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		c = "Kevin Ellersiek",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		c = "Maksim Povstugar",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		c = "Marek Klofera",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		c = "Matěj Ondráček",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		c = "Miroslav Halfar",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		c = "Maximilian Frömter",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		c = "Natalia Tkach",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		c = "Radek Švec",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		c = "Rastko Stanojević",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		c = "Raul Arencibia",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		c = "Reinaldo Artidiello",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		c = "Siddhant Patni",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		c = "Štěpán Bařina",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		c = "Vilen Saatsazov",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		c = "Vladimír Soukup",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		c = "Vladimir Silkin",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		c = "Vladyslav Vershytskyi",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		c = "Adii Parab",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		c = "Antonio Jose Gonzalez Benitez",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		c = "František Resl",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		c = "Gabi Kovarova",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		c = "Ilya Klishin",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		c = "Jaroslav Pijáček",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		c = "Jiří Světinský",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		c = "Jozef Rolincin",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		c = "Maria Panfilova",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		c = "Richard Vavruša",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		c = "Sergio Poderoso",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		c = "Tomáš Bujňák",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		c = "Thomas Flachs",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		t = CreditsScreen.SEPARATOR
	})
	table.insert(creditsTexts, {
		c = "Vehicle Integration",
		t = CreditsScreen.TITLE
	})
	table.insert(creditsTexts, {
		c = "Christian Wachter",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		c = "Daniel Witzel",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		c = "Niklas Schumacher",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		c = "Simon Nussel",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		c = "Stephan Bongartz",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		t = CreditsScreen.SEPARATOR
	})
	table.insert(creditsTexts, {
		c = "Lead Graphic Designer",
		t = CreditsScreen.TITLE
	})
	table.insert(creditsTexts, {
		c = "Sandra Meier",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		t = CreditsScreen.SEPARATOR
	})
	table.insert(creditsTexts, {
		c = "Graphic Designers",
		t = CreditsScreen.TITLE
	})
	table.insert(creditsTexts, {
		c = "Anett Jaschke",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		c = "Emelie Rissling",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		c = "Katrin Huber",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		c = "Michael Karg",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		t = CreditsScreen.SEPARATOR
	})
	table.insert(creditsTexts, {
		c = "Lead Audio Designer",
		t = CreditsScreen.TITLE
	})
	table.insert(creditsTexts, {
		c = "Kristian Caprani",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		t = CreditsScreen.SEPARATOR
	})
	table.insert(creditsTexts, {
		c = "Audio Designers",
		t = CreditsScreen.TITLE
	})
	table.insert(creditsTexts, {
		c = "Nils Heine",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		c = "Tiago Inácio",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		t = CreditsScreen.SEPARATOR
	})
	table.insert(creditsTexts, {
		c = "QA Lead",
		t = CreditsScreen.TITLE
	})
	table.insert(creditsTexts, {
		c = "Kenneth Burgess",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		t = CreditsScreen.SEPARATOR
	})
	table.insert(creditsTexts, {
		c = "QA Analysts",
		t = CreditsScreen.TITLE
	})
	table.insert(creditsTexts, {
		c = "Adrien Brüllmann",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		c = "Benjamin Neußinger",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		c = "Jana Stephan",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		c = "Loïck Ruß",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		c = "Marcel Renke",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		c = "Mario Vortkamp",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		c = "Martin Schücker",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		t = CreditsScreen.SEPARATOR
	})
	table.insert(creditsTexts, {
		c = "Head of Publishing",
		t = CreditsScreen.TITLE
	})
	table.insert(creditsTexts, {
		c = "Boris Stefan",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		t = CreditsScreen.SEPARATOR
	})
	table.insert(creditsTexts, {
		c = "Head of Marketing & PR",
		t = CreditsScreen.TITLE
	})
	table.insert(creditsTexts, {
		c = "Martin Rabl",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		t = CreditsScreen.SEPARATOR
	})
	table.insert(creditsTexts, {
		c = "PR & Marketing Managers",
		t = CreditsScreen.TITLE
	})
	table.insert(creditsTexts, {
		c = "Dennis Reisdorf",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		c = "Wolfgang Ebert",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		c = "Lukas Schreiner",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		t = CreditsScreen.SEPARATOR
	})
	table.insert(creditsTexts, {
		c = "Release Manager",
		t = CreditsScreen.TITLE
	})
	table.insert(creditsTexts, {
		c = "Carlo Sarti",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		t = CreditsScreen.SEPARATOR
	})
	table.insert(creditsTexts, {
		c = "Distribution Operations Manager",
		t = CreditsScreen.TITLE
	})
	table.insert(creditsTexts, {
		c = "Anna Ruß",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		t = CreditsScreen.SEPARATOR
	})
	table.insert(creditsTexts, {
		c = "Account Manager",
		t = CreditsScreen.TITLE
	})
	table.insert(creditsTexts, {
		c = "Martin Seidel",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		t = CreditsScreen.SEPARATOR
	})
	table.insert(creditsTexts, {
		c = "Technical Projects Coordinator",
		t = CreditsScreen.TITLE
	})
	table.insert(creditsTexts, {
		c = "Jan-Hendrik Pfitzner",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		t = CreditsScreen.SEPARATOR
	})
	table.insert(creditsTexts, {
		c = "Community Managers",
		t = CreditsScreen.TITLE
	})
	table.insert(creditsTexts, {
		c = "Christoph Stumpfer",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		c = "Kermit Ball",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		c = "Lars Malcharek",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		t = CreditsScreen.SEPARATOR
	})
	table.insert(creditsTexts, {
		c = "Customer Support Lead",
		t = CreditsScreen.TITLE
	})
	table.insert(creditsTexts, {
		c = "Christofer Zoltan",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		t = CreditsScreen.SEPARATOR
	})
	table.insert(creditsTexts, {
		c = "Customer Support Representatives",
		t = CreditsScreen.TITLE
	})
	table.insert(creditsTexts, {
		c = "Detlef Bövers",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		c = "Nicholas Frazier",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		t = CreditsScreen.SEPARATOR
	})
	table.insert(creditsTexts, {
		c = "Web Developers",
		t = CreditsScreen.TITLE
	})
	table.insert(creditsTexts, {
		c = "Fabian Seitz",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		c = "Felix Grelka",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		c = "Marten Boessenkool",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		c = "Rene Reisenweber",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		t = CreditsScreen.SEPARATOR
	})
	table.insert(creditsTexts, {
		c = "Lead Video Artist",
		t = CreditsScreen.TITLE
	})
	table.insert(creditsTexts, {
		c = "Michael Schraut",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		t = CreditsScreen.SEPARATOR
	})
	table.insert(creditsTexts, {
		c = "Video Artist",
		t = CreditsScreen.TITLE
	})
	table.insert(creditsTexts, {
		c = "Marco Riccardi",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		c = "Patrick Sander",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		c = "Timon Chevalier",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		t = CreditsScreen.SEPARATOR
	})
	table.insert(creditsTexts, {
		c = "Event Manager",
		t = CreditsScreen.TITLE
	})
	table.insert(creditsTexts, {
		c = "Claas Eilermann",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		c = "Jenny Wirsing",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		c = "Noah Geiger",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		t = CreditsScreen.SEPARATOR
	})
	table.insert(creditsTexts, {
		c = "Office Managers",
		t = CreditsScreen.TITLE
	})
	table.insert(creditsTexts, {
		c = "Adéla Štrajtová",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		c = "Chodon Fürer-Rikyog",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		c = "Pavel Válek",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		c = "Petra Erlbacher",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		t = CreditsScreen.SEPARATOR
	})
	table.insert(creditsTexts, {
		c = "Radio & Music",
		t = CreditsScreen.TITLE
	})
	table.insert(creditsTexts, {
		c = "Audio Network GmbH",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		t = CreditsScreen.SEPARATOR
	})
	table.insert(creditsTexts, {
		c = "External QA",
		t = CreditsScreen.TITLE
	})
	table.insert(creditsTexts, {
		c = "Testronic",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		t = CreditsScreen.SEPARATOR
	})
	table.insert(creditsTexts, {
		c = "Chief Service Officer",
		t = CreditsScreen.TITLE
	})
	table.insert(creditsTexts, {
		c = "Erik Hittenhausen",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		t = CreditsScreen.SEPARATOR
	})
	table.insert(creditsTexts, {
		c = "Director of QA",
		t = CreditsScreen.TITLE
	})
	table.insert(creditsTexts, {
		c = "Adam Biwojno",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		t = CreditsScreen.SEPARATOR
	})
	table.insert(creditsTexts, {
		c = "Director of Localisation QA",
		t = CreditsScreen.TITLE
	})
	table.insert(creditsTexts, {
		c = "Gaëlle Caballero",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		t = CreditsScreen.SEPARATOR
	})
	table.insert(creditsTexts, {
		c = "Functionality QA",
		t = CreditsScreen.TITLE
	})
	table.insert(creditsTexts, {
		c = "QA Project Manager",
		t = CreditsScreen.TITLE
	})
	table.insert(creditsTexts, {
		c = "Sebastian “Pablot” Kurek",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		t = CreditsScreen.SEPARATOR
	})
	table.insert(creditsTexts, {
		c = "QA Lead",
		t = CreditsScreen.TITLE
	})
	table.insert(creditsTexts, {
		c = "Tomasz Lewandowski",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		t = CreditsScreen.SEPARATOR
	})
	table.insert(creditsTexts, {
		c = "Associate QA Leads",
		t = CreditsScreen.TITLE
	})
	table.insert(creditsTexts, {
		c = "Anna Dąbrowska",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		c = "Dawid Szeliga",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		c = "Maria Koc",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		t = CreditsScreen.SEPARATOR
	})
	table.insert(creditsTexts, {
		c = "Functionality QA Technicians",
		t = CreditsScreen.TITLE
	})
	table.insert(creditsTexts, {
		c = "Kacper Szczytowski",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		c = "Krzysztof Sowa",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		c = "Łukasz Miecznikowski",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		c = "Maciej Powała",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		c = "Maciej Stępień",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		c = "Magdalena Bednarska",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		c = "Michał Pielech",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		c = "Natalia Krzewińska",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		c = "Paweł Pielech",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		c = "Shoakhmad Nazarov",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		t = CreditsScreen.SEPARATOR
	})
	table.insert(creditsTexts, {
		c = "Compliance QA",
		t = CreditsScreen.TITLE
	})
	table.insert(creditsTexts, {
		c = "Technical QA Manager",
		t = CreditsScreen.TITLE
	})
	table.insert(creditsTexts, {
		c = "Paweł “Piekarz” Kołnierzak",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		t = CreditsScreen.SEPARATOR
	})
	table.insert(creditsTexts, {
		c = "Technical Department Manager",
		t = CreditsScreen.TITLE
	})
	table.insert(creditsTexts, {
		c = "Iwona Szarzyńska",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		t = CreditsScreen.SEPARATOR
	})
	table.insert(creditsTexts, {
		c = "Senior Technical Project Lead",
		t = CreditsScreen.TITLE
	})
	table.insert(creditsTexts, {
		c = "Małgorzata Twarogal",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		t = CreditsScreen.SEPARATOR
	})
	table.insert(creditsTexts, {
		c = "Technical Project Lead",
		t = CreditsScreen.TITLE
	})
	table.insert(creditsTexts, {
		c = "Michał “Bobson” Radłowski",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		t = CreditsScreen.SEPARATOR
	})
	table.insert(creditsTexts, {
		c = "Senior Technical QA Analysts",
		t = CreditsScreen.TITLE
	})
	table.insert(creditsTexts, {
		c = "Adrian “Dorian” Strzelecki",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		c = "Dorian “Tradey” Geisler",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		t = CreditsScreen.SEPARATOR
	})
	table.insert(creditsTexts, {
		c = "Technical QA Analysts",
		t = CreditsScreen.TITLE
	})
	table.insert(creditsTexts, {
		c = "Adam Marczak",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		c = "Jakub Neyman",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		c = "Justyna Fundowicz",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		c = "Krzysztof Skóra",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		t = CreditsScreen.SEPARATOR
	})
	table.insert(creditsTexts, {
		c = "Compliance QA Technicians",
		t = CreditsScreen.TITLE
	})
	table.insert(creditsTexts, {
		c = "Agata Dylak",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		c = "Aneta Majek",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		c = "Jakub Babula",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		c = "Katarzyna Kalbarczyk",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		c = "Łukasz Korolkiewicz",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		t = CreditsScreen.SEPARATOR
	})
	table.insert(creditsTexts, {
		c = "Compatibility QA",
		t = CreditsScreen.TITLE
	})
	table.insert(creditsTexts, {
		c = "Technical QA Manager",
		t = CreditsScreen.TITLE
	})
	table.insert(creditsTexts, {
		c = "Paweł “Piekarz” Kołnierzak",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		t = CreditsScreen.SEPARATOR
	})
	table.insert(creditsTexts, {
		c = "Technical Department Manager",
		t = CreditsScreen.TITLE
	})
	table.insert(creditsTexts, {
		c = "Iwona Szarzyńska",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		t = CreditsScreen.SEPARATOR
	})
	table.insert(creditsTexts, {
		c = "Associate Technical QA Leads",
		t = CreditsScreen.TITLE
	})
	table.insert(creditsTexts, {
		c = "Alan Parsons",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		c = "Michał Soral",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		t = CreditsScreen.SEPARATOR
	})
	table.insert(creditsTexts, {
		c = "Compatibility QA Technicians",
		t = CreditsScreen.TITLE
	})
	table.insert(creditsTexts, {
		c = "Bartłomiej “Akur” Stajkowski",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		c = "Dorian “Tradey” Geisler",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		c = "Łukasz Sobolewski",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		c = "Paweł Kandyba",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		t = CreditsScreen.SEPARATOR
	})
	table.insert(creditsTexts, {
		c = "Localisation QA",
		t = CreditsScreen.TITLE
	})
	table.insert(creditsTexts, {
		c = "Senior Localisation QA Manager",
		t = CreditsScreen.TITLE
	})
	table.insert(creditsTexts, {
		c = "Valentina Mollica",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		t = CreditsScreen.SEPARATOR
	})
	table.insert(creditsTexts, {
		c = "Localisation QA Manager",
		t = CreditsScreen.TITLE
	})
	table.insert(creditsTexts, {
		c = "Jouhaina Ramy",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		t = CreditsScreen.SEPARATOR
	})
	table.insert(creditsTexts, {
		c = "Localisation QA Project Manager",
		t = CreditsScreen.TITLE
	})
	table.insert(creditsTexts, {
		c = "Krzysztof Orlikowski",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		t = CreditsScreen.SEPARATOR
	})
	table.insert(creditsTexts, {
		c = "Localisation QA Lead",
		t = CreditsScreen.TITLE
	})
	table.insert(creditsTexts, {
		c = "Jamie Kelly-Warwick",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		t = CreditsScreen.SEPARATOR
	})
	table.insert(creditsTexts, {
		c = "Senior Localisation QA Technicians",
		t = CreditsScreen.TITLE
	})
	table.insert(creditsTexts, {
		c = "Anthony Brian Yuen",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		c = "Charlotte Cameron",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		c = "Dennis Born",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		c = "Jefta de Cock",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		c = "Keiko Naito",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		c = "Morten Østergaard",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		c = "Piotr Rokitnicki",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		t = CreditsScreen.SEPARATOR
	})
	table.insert(creditsTexts, {
		c = "Localisation QA Technicians",
		t = CreditsScreen.TITLE
	})
	table.insert(creditsTexts, {
		c = "Álvaro Saavedra Jeno",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		c = "Brice José Fajardo Ory",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		c = "Cristina Baleanu",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		c = "Davide Fanni",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		c = "Jaehun Bae",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		c = "Kan Cheng",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		c = "Katarzyna Maciejewska",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		c = "Marcela Ostrochovska",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		c = "Marilia Stieven Sonza",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		c = "Pál Veres Kovács",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		c = "Roksolana Krushenytska",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		c = "Stephen Bubenheim",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		t = CreditsScreen.SEPARATOR
	})

	if not Platform.isStadia and (not Platform.isPC or g_languageShort ~= "de" and g_languageShort ~= "pl" and g_languageShort ~= "cz" and g_languageShort ~= "hu" and g_languageShort ~= "ro") and Platform.territory == "jp" then
		table.insert(creditsTexts, {
			t = CreditsScreen.SEPARATOR
		})
		table.insert(creditsTexts, {
			c = "Licensed to and published in Japan by ",
			t = CreditsScreen.TITLE
		})
		table.insert(creditsTexts, {
			c = "Bandai Namco Entertainment Inc.",
			t = CreditsScreen.TEXT
		})
		table.insert(creditsTexts, {
			t = CreditsScreen.SEPARATOR
		})
	end

	table.insert(creditsTexts, {
		c = "",
		t = CreditsScreen.DISCLAIMER
	})
	table.insert(creditsTexts, {
		c = "",
		t = CreditsScreen.DISCLAIMER
	})
	table.insert(creditsTexts, {
		t = CreditsScreen.DISCLAIMER,
		c = "Copyright " .. g_i18n:getText("ui_copyrightSymbol") .. " 2003-2021 GIANTS Software GmbH"
	})
	table.insert(creditsTexts, {
		c = "Farming Simulator",
		t = CreditsScreen.DISCLAIMER
	})
	table.insert(creditsTexts, {
		c = "GIANTS Software and its logos are trademarks",
		t = CreditsScreen.DISCLAIMER
	})
	table.insert(creditsTexts, {
		c = "or registered trademarks of GIANTS Software",
		t = CreditsScreen.DISCLAIMER
	})
	table.insert(creditsTexts, {
		c = "All rights reserved.",
		t = CreditsScreen.DISCLAIMER
	})
	table.insert(creditsTexts, {
		c = "",
		t = CreditsScreen.DISCLAIMER
	})
	table.insert(creditsTexts, {
		t = CreditsScreen.SEPARATOR
	})
	table.insert(creditsTexts, {
		c = "All manufacturers, agricultural machinery,",
		t = CreditsScreen.DISCLAIMER
	})
	table.insert(creditsTexts, {
		c = "agricultural equipment, names, brands and",
		t = CreditsScreen.DISCLAIMER
	})
	table.insert(creditsTexts, {
		c = "associated imagery featured in this game",
		t = CreditsScreen.DISCLAIMER
	})
	table.insert(creditsTexts, {
		c = "in some cases include trademarks and/or",
		t = CreditsScreen.DISCLAIMER
	})
	table.insert(creditsTexts, {
		c = "copyrighted materials of their",
		t = CreditsScreen.DISCLAIMER
	})
	table.insert(creditsTexts, {
		c = "respective owners. The agricultural",
		t = CreditsScreen.DISCLAIMER
	})
	table.insert(creditsTexts, {
		c = "machines and equipment in this game",
		t = CreditsScreen.DISCLAIMER
	})
	table.insert(creditsTexts, {
		c = "may be different from the actual machines",
		t = CreditsScreen.DISCLAIMER
	})
	table.insert(creditsTexts, {
		c = "in shapes, colours and performance.",
		t = CreditsScreen.DISCLAIMER
	})
	table.insert(creditsTexts, {
		c = "",
		t = CreditsScreen.DISCLAIMER
	})
	table.insert(creditsTexts, {
		t = CreditsScreen.SEPARATOR
	})
	table.insert(creditsTexts, {
		c = "The VOLVO trademarks (word and device),",
		t = CreditsScreen.DISCLAIMER
	})
	table.insert(creditsTexts, {
		c = "other related trademarks, if applicable, ",
		t = CreditsScreen.DISCLAIMER
	})
	table.insert(creditsTexts, {
		c = "and the Volvo designs are licensed by",
		t = CreditsScreen.DISCLAIMER
	})
	table.insert(creditsTexts, {
		c = "the AB Volvo Group.",
		t = CreditsScreen.DISCLAIMER
	})
	table.insert(creditsTexts, {
		c = "",
		t = CreditsScreen.DISCLAIMER
	})
	table.insert(creditsTexts, {
		t = CreditsScreen.SEPARATOR
	})

	if not GS_PLATFORM_XBOX and not GS_IS_MOBILE_VERSION then
		table.insert(creditsTexts, {
			t = CreditsScreen.DISCLAIMER,
			c = g_i18n:getText("ui_copyrightSymbol") .. " 2021 Sony Interactive Entertainment LLC."
		})
		table.insert(creditsTexts, {
			c = "\"PlayStation Family Mark\", \"PlayStation\",",
			t = CreditsScreen.DISCLAIMER
		})
		table.insert(creditsTexts, {
			c = "\"PS5 logo\", \"PS5\", \"PS4 logo\", \"PS4\",",
			t = CreditsScreen.DISCLAIMER
		})
		table.insert(creditsTexts, {
			c = "\"PlayStation Shapes Logo\" and \"Play Has No Limits\"",
			t = CreditsScreen.DISCLAIMER
		})
		table.insert(creditsTexts, {
			c = "are registered trademarks or trademarks of",
			t = CreditsScreen.DISCLAIMER
		})
		table.insert(creditsTexts, {
			c = "Sony Interactive Entertainment Inc.",
			t = CreditsScreen.DISCLAIMER
		})
		table.insert(creditsTexts, {
			c = "",
			t = CreditsScreen.DISCLAIMER
		})
	end

	table.insert(creditsTexts, {
		c = "Uses Lua",
		t = CreditsScreen.DISCLAIMER
	})
	table.insert(creditsTexts, {
		t = CreditsScreen.DISCLAIMER,
		c = "Copyright " .. g_i18n:getText("ui_copyrightSymbol") .. " 1994-2021 Lua.org, PUC-Rio"
	})
	table.insert(creditsTexts, {
		c = "",
		t = CreditsScreen.DISCLAIMER
	})
	table.insert(creditsTexts, {
		t = CreditsScreen.SEPARATOR
	})
	table.insert(creditsTexts, {
		c = "Uses LuaJIT",
		t = CreditsScreen.DISCLAIMER
	})
	table.insert(creditsTexts, {
		t = CreditsScreen.DISCLAIMER,
		c = "Copyright " .. g_i18n:getText("ui_copyrightSymbol") .. " 2005-2021 Mike Pall"
	})
	table.insert(creditsTexts, {
		c = "",
		t = CreditsScreen.DISCLAIMER
	})
	table.insert(creditsTexts, {
		t = CreditsScreen.SEPARATOR
	})
	table.insert(creditsTexts, {
		c = "Uses Ogg Vorbis",
		t = CreditsScreen.DISCLAIMER
	})
	table.insert(creditsTexts, {
		t = CreditsScreen.DISCLAIMER,
		c = "Copyright " .. g_i18n:getText("ui_copyrightSymbol") .. " 1994-2021 Xiph.Org Foundation"
	})
	table.insert(creditsTexts, {
		c = "",
		t = CreditsScreen.DISCLAIMER
	})
	table.insert(creditsTexts, {
		t = CreditsScreen.SEPARATOR
	})
	table.insert(creditsTexts, {
		c = "Uses Zlib",
		t = CreditsScreen.DISCLAIMER
	})
	table.insert(creditsTexts, {
		t = CreditsScreen.DISCLAIMER,
		c = "Copyright " .. g_i18n:getText("ui_copyrightSymbol") .. " 1995-2021 Jean-loup Gailly"
	})
	table.insert(creditsTexts, {
		c = "and Mark Adler",
		t = CreditsScreen.DISCLAIMER
	})
	table.insert(creditsTexts, {
		c = "",
		t = CreditsScreen.DISCLAIMER
	})
	table.insert(creditsTexts, {
		t = CreditsScreen.SEPARATOR
	})
	table.insert(creditsTexts, {
		c = "This software is based in part on",
		t = CreditsScreen.DISCLAIMER
	})
	table.insert(creditsTexts, {
		c = "the work of the Independent JPEG Group",
		t = CreditsScreen.DISCLAIMER
	})
	table.insert(creditsTexts, {
		t = CreditsScreen.DISCLAIMER,
		c = "Copyright " .. g_i18n:getText("ui_copyrightSymbol") .. " 1991-2021 Independent JPEG Group"
	})
	table.insert(creditsTexts, {
		t = CreditsScreen.SEPARATOR
	})
	table.insert(creditsTexts, {
		c = "",
		t = CreditsScreen.TITLE
	})
	table.insert(creditsTexts, {
		c = "",
		t = CreditsScreen.TITLE
	})
	table.insert(creditsTexts, {
		c = "",
		t = CreditsScreen.TITLE
	})
	table.insert(creditsTexts, {
		c = "",
		t = CreditsScreen.TITLE
	})
	table.insert(creditsTexts, {
		c = "",
		t = CreditsScreen.TITLE
	})
	table.insert(creditsTexts, {
		c = "",
		t = CreditsScreen.TITLE
	})
	table.insert(creditsTexts, {
		t = CreditsScreen.SEPARATOR
	})
	table.insert(creditsTexts, {
		c = "Special Thanks to",
		t = CreditsScreen.TITLE
	})
	table.insert(creditsTexts, {
		c = "Martin Bärwolf",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		c = "Mike Pall",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		c = "Andrés Villegas",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		c = "Brian Burgess",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		t = CreditsScreen.SEPARATOR
	})
	table.insert(creditsTexts, {
		c = "",
		t = CreditsScreen.TITLE
	})
	table.insert(creditsTexts, {
		c = "",
		t = CreditsScreen.TITLE
	})
	table.insert(creditsTexts, {
		c = "",
		t = CreditsScreen.TITLE
	})
	table.insert(creditsTexts, {
		c = "",
		t = CreditsScreen.TITLE
	})
	table.insert(creditsTexts, {
		c = "",
		t = CreditsScreen.TITLE
	})
	table.insert(creditsTexts, {
		c = "",
		t = CreditsScreen.TITLE
	})
	table.insert(creditsTexts, {
		c = "",
		t = CreditsScreen.TITLE
	})
	table.insert(creditsTexts, {
		c = "",
		t = CreditsScreen.TITLE
	})
	table.insert(creditsTexts, {
		c = "",
		t = CreditsScreen.TITLE
	})
	table.insert(creditsTexts, {
		c = "",
		t = CreditsScreen.TITLE
	})
	table.insert(creditsTexts, {
		c = "",
		t = CreditsScreen.TITLE
	})
	table.insert(creditsTexts, {
		c = "",
		t = CreditsScreen.TITLE
	})
	table.insert(creditsTexts, {
		c = "",
		t = CreditsScreen.TITLE
	})
	table.insert(creditsTexts, {
		c = "",
		t = CreditsScreen.TITLE
	})
	table.insert(creditsTexts, {
		c = "Thanks for playing!",
		t = CreditsScreen.TEXT
	})
	table.insert(creditsTexts, {
		c = "",
		t = CreditsScreen.TITLE
	})
	table.insert(creditsTexts, {
		c = "",
		t = CreditsScreen.TITLE
	})
	table.insert(creditsTexts, {
		c = "",
		t = CreditsScreen.TITLE
	})
	table.insert(creditsTexts, {
		c = "",
		t = CreditsScreen.TITLE
	})
	table.insert(creditsTexts, {
		c = "",
		t = CreditsScreen.TITLE
	})
	table.insert(creditsTexts, {
		c = "",
		t = CreditsScreen.TITLE
	})
	table.insert(creditsTexts, {
		c = "",
		t = CreditsScreen.TITLE
	})
	table.insert(creditsTexts, {
		c = "",
		t = CreditsScreen.TITLE
	})
	table.insert(creditsTexts, {
		c = "",
		t = CreditsScreen.TITLE
	})

	for i = #self.creditsPlaceholder.elements, 1, -1 do
		self.creditsPlaceholder.elements[i]:delete()
	end

	self.creditsElements = {}

	for _, creditsElem in pairs(creditsTexts) do
		self.currentCreditsText = creditsElem.c
		local newCreditsElem = nil

		if creditsElem.t == CreditsScreen.TITLE then
			newCreditsElem = self.creditsTitleElement:clone(self.creditsPlaceholder)

			newCreditsElem:updateSize()
			newCreditsElem:setText(creditsElem.c)
		elseif creditsElem.t == CreditsScreen.TEXT then
			newCreditsElem = self.creditsTextElement:clone(self.creditsPlaceholder)

			newCreditsElem:setText(creditsElem.c)
		elseif creditsElem.t == CreditsScreen.DISCLAIMER then
			newCreditsElem = self.creditsDisclaimerElement:clone(self.creditsPlaceholder)

			newCreditsElem:setText(creditsElem.c)
		end

		if newCreditsElem ~= nil then
			newCreditsElem:setAlpha(0)
			table.insert(self.creditsElements, newCreditsElem)
		end
	end

	local height = self.creditsPlaceholder:invalidateLayout(true)
	self.creditsEndY = self.creditsPlaceholder.size[2] + height
end

function CreditsScreen:onCareerClick(element)
	self:changeScreen(MainScreen)
	FocusManager:setFocus(g_mainScreen.careerButton)
	g_mainScreen:onCareerClick(element)
end

function CreditsScreen:onAchievementsClick(element)
	self:changeScreen(MainScreen)
	FocusManager:setFocus(g_mainScreen.achievementsButton)
	g_mainScreen:onAchievementsClick(element)
end
