// SPDX-FileCopyrightText: 2007-2010, 2013-2016, 2018, 2024, 2026 SpeedCrunch developers
// SPDX-License-Identifier: GPL-2.0-or-later
//
// macOS fork: drop-in replacement for src/core/settings.cpp that depends only
// on QtCore. Persistence is owned by the Swift app (UserDefaults), which pushes
// values in through the C bridge, so load()/save() only establish defaults.

#include "core/settings.h"

#include "core/complexform.h"
#include "core/mathdsl.h"

#include <QLocale>

static Settings* s_settingsInstance = nullptr;
static char s_radixCharacter = 0;

Settings* Settings::instance()
{
    if (!s_settingsInstance) {
        s_settingsInstance = new Settings;
        s_settingsInstance->load();
    }
    return s_settingsInstance;
}

QString Settings::getConfigPath() { return QString(); }
QString Settings::getDataPath() { return QString(); }
QString Settings::getCachePath() { return QString(); }

Settings::CustomKeypad Settings::defaultCustomKeypad()
{
    CustomKeypad custom;
    custom.rows = 0;
    custom.columns = 0;
    return custom;
}

Settings::Settings()
{
    digitGroupingIntegerPartOnly = true;
    numberFormatStyle = NumberFormatNoGroupingDot;
    hasNumberFormatStyleSetting = false;
    simplifyResultExpressions = true;
    complexNumbers = true;
    imaginaryUnit = 'i';
    autoCompletionBuiltInFunctions = true;
    autoCompletionBuiltInVariables = true;
    autoCompletionLongFormUnits = true;
    autoCompletionUserFunctions = true;
    autoCompletionUserVariables = true;
    secondaryResultPrecision = -1;
    resultRoundingMode = ResultRoundingHalfAwayFromZero;
    unitNegativeExponentStyle = UnitNegativeExponentSuperscript;
    tertiaryResultPrecision = -1;
    quaternaryResultPrecision = -1;
    quinaryResultPrecision = -1;
    secondaryResultEnabled = false;
    tertiaryResultEnabled = false;
    quaternaryResultEnabled = false;
    quinaryResultEnabled = false;
    multipleResultLinesEnabled = false;
    secondaryComplexNumbers = true;
    resultComplexForm = ComplexForm::Default;
    secondaryResultComplexForm = ComplexForm::Default;
    tertiaryComplexNumbers = true;
    tertiaryResultComplexForm = ComplexForm::Default;
    quaternaryComplexNumbers = true;
    quaternaryResultComplexForm = ComplexForm::Default;
    quinaryComplexNumbers = true;
    quinaryResultComplexForm = ComplexForm::Default;

    setRuntimeUnitNegativeExponentStyle(unitNegativeExponentStyle);
    setRuntimeResultRoundingMode(resultRoundingMode);
}

void Settings::load()
{
    angleUnit = 'r';
    autoAns = false;
    autoCalc = true;
    autoCompletion = true;
    upDownArrowBehavior = UpDownArrowBehaviorAlways;
    leaveLastExpression = false;
    showEmptyHistoryHint = true;
    language = QStringLiteral("C");
    syntaxHighlighting = true;
    hoverHighlightResults = true;
    autoResultToClipboard = false;
    windowPositionSave = false;
    digitGrouping = 0;
    resultFormat = 'g';
    alternativeResultFormat = '\0';
    tertiaryResultFormat = '\0';
    quaternaryResultFormat = '\0';
    quinaryResultFormat = '\0';
    resultPrecision = -1;
    constantsDockVisible = false;
    functionsDockVisible = false;
    historyDockVisible = false;
    keypadVisible = false;
    keypadMode = KeypadModeDisabled;
    keypadZoomPercent = 100;
    customKeypad = defaultCustomKeypad();
    formulaBookDockVisible = false;
    statusBarVisible = false;
    menuBarVisible = true;
    variablesDockVisible = false;
    userFunctionsDockVisible = false;
    userUnitsDockVisible = false;
    windowOnfullScreen = false;
    windowAlwaysOnTop = false;
    bitfieldVisible = false;
    applyNumberFormatStyle();
}

void Settings::save() { }
void Settings::saveSessionLayoutJson() { }

char Settings::radixCharacter() const
{
    if (isRadixCharacterAuto() || isRadixCharacterBoth()) {
        #if QT_VERSION >= QT_VERSION_CHECK(6, 0, 0)
            // In Qt 6, decimalPoint returns a QString
            QChar decimalPoint = QLocale().decimalPoint().at(0);
        #else
            // In Qt 5, decimalPoint returns a QChar
            QChar decimalPoint = QLocale().decimalPoint();
        #endif
        return decimalPoint.toLatin1();
    }

    return s_radixCharacter;
}

char Settings::decimalSeparator() const
{
    switch (numberFormatStyle) {
    case NumberFormatNoGroupingComma:
    case NumberFormatThreeDigitDotComma:
    case NumberFormatThreeDigitSpaceComma:
    case NumberFormatSIComma:
    case NumberFormatThreeDigitUnderscoreComma:
    case NumberFormatThreeDigitDotCommaFraction:
    case NumberFormatThreeDigitUnderscoreCommaFraction:
        return MathDsl::CommaSep.toLatin1();
    case NumberFormatSIDot:
    case NumberFormatNoGroupingDot:
    case NumberFormatThreeDigitCommaDot:
    case NumberFormatThreeDigitCommaDotFraction:
    case NumberFormatThreeDigitSpaceDot:
    case NumberFormatThreeDigitUnderscoreDot:
    case NumberFormatThreeDigitUnderscoreDotFraction:
    case NumberFormatIndianCommaDot:
    default:
        return MathDsl::DotSep.toLatin1();
    }
}

bool Settings::isRadixCharacterAuto() const
{
    return s_radixCharacter == 0;
}

bool Settings::isRadixCharacterBoth() const
{
    return s_radixCharacter == MathDsl::MulOpAl1.toLatin1();
}

void Settings::setRadixCharacter(char c)
{
    s_radixCharacter = (c != MathDsl::CommaSep.toLatin1()
                        && c != MathDsl::DotSep.toLatin1()
                        && c != MathDsl::MulOpAl1.toLatin1())
        ? 0
        : c;
}

void Settings::applyNumberFormatStyle()
{
    switch (numberFormatStyle) {
    case NumberFormatNoGroupingDot:
    case NumberFormatSIDot:
    case NumberFormatThreeDigitCommaDot:
    case NumberFormatThreeDigitCommaDotFraction:
    case NumberFormatThreeDigitSpaceDot:
    case NumberFormatThreeDigitUnderscoreDot:
    case NumberFormatThreeDigitUnderscoreDotFraction:
    case NumberFormatIndianCommaDot:
        setRadixCharacter(MathDsl::DotSep.toLatin1());
        break;
    case NumberFormatNoGroupingComma:
    case NumberFormatSIComma:
    case NumberFormatThreeDigitDotComma:
    case NumberFormatThreeDigitDotCommaFraction:
    case NumberFormatThreeDigitSpaceComma:
    case NumberFormatThreeDigitUnderscoreComma:
    case NumberFormatThreeDigitUnderscoreCommaFraction:
        setRadixCharacter(MathDsl::CommaSep.toLatin1());
        break;
    case NumberFormatSystem:
    default:
        setRadixCharacter(MathDsl::DotSep.toLatin1());
        break;
    }

    // Legacy syntax-highlighter spacing should stay disabled; grouping is now
    // represented explicitly by concrete separators in formatted text.
    digitGrouping = 0;
    switch (numberFormatStyle) {
    case NumberFormatSIDot:
    case NumberFormatSIComma:
    case NumberFormatThreeDigitCommaDotFraction:
    case NumberFormatThreeDigitDotCommaFraction:
    case NumberFormatThreeDigitUnderscoreDotFraction:
    case NumberFormatThreeDigitUnderscoreCommaFraction:
        digitGroupingIntegerPartOnly = false;
        break;
    default:
        digitGroupingIntegerPartOnly = true;
        break;
    }
}

bool Settings::isDigitGroupingEnabled() const
{
    return numberFormatStyle != NumberFormatNoGroupingDot
        && numberFormatStyle != NumberFormatNoGroupingComma;
}

bool Settings::isIndianDigitGrouping() const
{
    return numberFormatStyle == NumberFormatIndianCommaDot;
}

QString Settings::digitGroupingSeparator() const
{
    if (!isDigitGroupingEnabled())
        return QString();

    switch (numberFormatStyle) {
    case NumberFormatSIDot:
    case NumberFormatSIComma:
    case NumberFormatThreeDigitSpaceDot:
    case NumberFormatThreeDigitSpaceComma:
        return QStringLiteral(" ");
    case NumberFormatThreeDigitCommaDot:
    case NumberFormatThreeDigitCommaDotFraction:
    case NumberFormatIndianCommaDot:
        return QStringLiteral(",");
    case NumberFormatThreeDigitDotComma:
    case NumberFormatThreeDigitDotCommaFraction:
        return QStringLiteral(".");
    case NumberFormatThreeDigitUnderscoreDot:
    case NumberFormatThreeDigitUnderscoreDotFraction:
    case NumberFormatThreeDigitUnderscoreComma:
    case NumberFormatThreeDigitUnderscoreCommaFraction:
        return QStringLiteral("_");
    default:
        return QString();
    }
}

