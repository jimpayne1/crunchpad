// SPDX-License-Identifier: GPL-2.0-or-later

#include "SpeedCrunchEngine.h"

#include "core/book.h"
#include "core/constants.h"
#include "core/evaluator.h"
#include "core/functions.h"
#include "core/numberformatter.h"
#include "core/settings.h"
#include "math/cmath.h"

#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>

#include <cstdlib>
#include <cstring>

namespace {

Evaluator* evaluator()
{
    return Evaluator::instance();
}

char* dup(const QByteArray& bytes)
{
    char* out = static_cast<char*>(std::malloc(size_t(bytes.size()) + 1));
    std::memcpy(out, bytes.constData(), size_t(bytes.size()));
    out[bytes.size()] = '\0';
    return out;
}

char* toJson(const QJsonObject& obj)
{
    return dup(QJsonDocument(obj).toJson(QJsonDocument::Compact));
}

char* toJson(const QJsonArray& arr)
{
    return dup(QJsonDocument(arr).toJson(QJsonDocument::Compact));
}

QString str(const char* s)
{
    return s ? QString::fromUtf8(s) : QString();
}

char* runEvaluation(const char* raw, bool commit)
{
    Evaluator* ev = evaluator();
    const QString entered = str(raw);
    const QString expr = ev->autoFix(entered);
    const bool commentOnly = Evaluator::isCommentOnlyExpression(expr);

    QJsonObject out;
    out["expression"] = entered;
    if (expr.trimmed().isEmpty()) {
        out["ok"] = true;
        out["kind"] = "none";
        return toJson(out);
    }

    ev->setExpression(expr);
    Quantity result = commit ? ev->evalUpdateAns() : ev->evalNoAssign();

    if (!ev->error().isEmpty()) {
        out["ok"] = false;
        out["error"] = ev->error();
        return toJson(out);
    }

    QString kind = QStringLiteral("value");
    if (ev->isUserFunctionAssign()) {
        kind = QStringLiteral("function");
        result = CMath::nan();
    } else if (ev->isUserUnitAssign()) {
        kind = QStringLiteral("unit");
        result = CMath::nan();
    } else if (commentOnly) {
        kind = QStringLiteral("comment");
    } else if (result.isNan()) {
        out["ok"] = true;
        out["kind"] = "none";
        return toJson(out);
    } else if (ev->isUserVariableAssign()) {
        kind = QStringLiteral("variable");
    }

    const QString interpreted = ev->interpretedExpression();
    out["ok"] = true;
    out["kind"] = kind;
    out["interpreted"] = Settings::instance()->simplifyResultExpressions
        ? Evaluator::formatInterpretedExpressionSimplifiedForDisplay(interpreted, ev)
        : Evaluator::formatInterpretedExpressionForDisplay(interpreted, ev);
    if (!result.isNan()) {
        out["result"] = NumberFormatter::format(result);
        // Binary digits for the bit field (integers only, sign dropped).
        if (result.isInteger() && !result.isZero()) {
            QString bin = NumberFormatter::format(result, 'b');
            bin.remove(QLatin1Char('-')).remove(QChar(0x2212)).remove(QStringLiteral("0b"));
            out["bits"] = bin;
        }
    }
    return toJson(out);
}

} // namespace

extern "C" {

void sc_init(void)
{
    Settings::instance();
    FunctionRepo::instance();
    Constants::instance();
    evaluator()->initializeBuiltInVariables();
}

void sc_free(char* s)
{
    std::free(s);
}

char* sc_evaluate(const char* expr)
{
    return runEvaluation(expr, true);
}

char* sc_preview(const char* expr)
{
    return runEvaluation(expr, false);
}

void sc_apply_settings(const char* json)
{
    const QJsonObject o = QJsonDocument::fromJson(QByteArray(json)).object();
    Settings* s = Settings::instance();
    auto ch = [&](const char* key, char fallback) {
        const QString v = o.value(QLatin1String(key)).toString();
        return v.isEmpty() ? fallback : v.at(0).toLatin1();
    };

    const char previousAngle = s->angleUnit;
    s->angleUnit = ch("angleUnit", s->angleUnit);
    s->resultFormat = ch("resultFormat", s->resultFormat);
    s->resultPrecision = o.value("precision").toInt(s->resultPrecision);
    s->complexNumbers = o.value("complexNumbers").toBool(s->complexNumbers);
    s->resultComplexForm = ch("complexForm", s->resultComplexForm);
    s->imaginaryUnit = ch("imaginaryUnit", s->imaginaryUnit);
    s->simplifyResultExpressions = o.value("simplify").toBool(s->simplifyResultExpressions);
    if (o.contains("numberFormatStyle")) {
        s->numberFormatStyle = Settings::NumberFormatStyle(o.value("numberFormatStyle").toInt());
        s->hasNumberFormatStyleSetting = true;
        s->applyNumberFormatStyle();
    }

    // The upstream GUI re-seeds built-ins (i/j, angle units) after these
    // settings change; do the same so `i`, `°`, etc. stay consistent.
    if (previousAngle != s->angleUnit)
        evaluator()->initializeAngleUnits();
    evaluator()->initializeBuiltInVariables();
}

char* sc_builtin_functions(void)
{
    QJsonArray arr;
    FunctionRepo* repo = FunctionRepo::instance();
    QStringList ids = repo->getIdentifiers();
    ids.sort(Qt::CaseInsensitive);
    for (const QString& id : ids) {
        if (repo->displayIdentifier(id) != id)
            continue; // Skip aliases.
        const Function* f = repo->find(id);
        if (!f)
            continue;
        QJsonObject o;
        o["id"] = id;
        o["name"] = f->name();
        o["usage"] = f->usage();
        o["domain"] = f->domain();
        arr.append(o);
    }
    return toJson(arr);
}

char* sc_constants(void)
{
    QJsonArray arr;
    for (const Constant& c : Constants::instance()->list()) {
        QJsonObject o;
        o["name"] = c.name;
        o["value"] = c.value;
        o["unit"] = c.unit;
        o["domain"] = c.domain;
        o["subdomain"] = c.subdomain;
        arr.append(o);
    }
    return toJson(arr);
}

char* sc_user_variables(void)
{
    QJsonArray arr;
    for (const Variable& v : evaluator()->getUserDefinedVariablesPlusAns()) {
        QJsonObject o;
        o["id"] = v.identifier();
        o["value"] = NumberFormatter::format(v.value());
        o["description"] = v.description();
        arr.append(o);
    }
    return toJson(arr);
}

char* sc_user_functions(void)
{
    QJsonArray arr;
    for (const UserFunction& f : evaluator()->getUserFunctions()) {
        QJsonObject o;
        o["name"] = f.name();
        o["args"] = QJsonArray::fromStringList(f.arguments());
        o["expression"] = f.expression();
        o["description"] = f.description();
        arr.append(o);
    }
    return toJson(arr);
}

char* sc_user_units(void)
{
    QJsonArray arr;
    for (const UserUnit& u : evaluator()->getUserUnits()) {
        QJsonObject o;
        o["name"] = u.name();
        o["expression"] = u.expression();
        o["description"] = u.description();
        arr.append(o);
    }
    return toJson(arr);
}

char* sc_completions(const char* rawPrefix)
{
    const QString prefix = str(rawPrefix);
    QJsonArray arr;
    if (prefix.isEmpty())
        return toJson(arr);

    auto add = [&](const QString& text, const char* kind, const QString& detail) {
        if (!text.startsWith(prefix, Qt::CaseInsensitive) || text == prefix)
            return;
        QJsonObject o;
        o["text"] = text;
        o["kind"] = kind;
        o["detail"] = detail;
        arr.append(o);
    };

    FunctionRepo* repo = FunctionRepo::instance();
    for (const QString& id : repo->getIdentifiers()) {
        if (const Function* f = repo->find(id))
            add(id, "function", f->name());
    }
    for (const UserFunction& f : evaluator()->getUserFunctions())
        add(f.name(), "userFunction", f.expression());
    for (const Variable& v : evaluator()->getVariables())
        add(v.identifier(), v.type() == Variable::BuiltIn ? "constant" : "variable",
            NumberFormatter::format(v.value()));
    for (const QString& u : evaluator()->allUnitIdentifiers())
        add(u, "unit", QString());

    return toJson(arr);
}

char* sc_book_page(const char* id)
{
    static Book* book = new Book;
    const QString page = book->getPageContent(str(id).isEmpty() ? QStringLiteral("index") : str(id));
    return dup(page.toUtf8());
}

void sc_unset_variable(const char* id)
{
    evaluator()->unsetVariable(str(id));
}

void sc_unset_function(const char* name)
{
    evaluator()->unsetUserFunction(str(name));
}

void sc_unset_unit(const char* name)
{
    evaluator()->unsetUserUnit(str(name));
}

void sc_reset(void)
{
    Evaluator* ev = evaluator();
    ev->unsetAllUserDefinedVariables();
    ev->unsetAllUserFunctions();
    ev->unsetAllUserUnits();
    ev->unsetVariable(QStringLiteral("ans"), true);
    ev->initializeBuiltInVariables();
}

} // extern "C"
