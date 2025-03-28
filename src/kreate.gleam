import gleam/io
import gleam/option.{None, Some}
import gleam/result
import gleam/set
import gleam/string
import nibble.{do}
import nibble/lexer
import simplifile

type Kw {
  Classifier
  Feature
}

type Cr {
  Specializes
}

type Fr {
  TypedBy
  Subsets
  Redefines
}

type Token {
  Keyword(Kw)
  Name(String)
  LBracket
  RBracket
  Integer(Int)
  Until
  LBrace
  RBrace
  ClassifierRelation(Cr)
  FeatureRelation(Fr)
  Colon
  Semicolon
}

pub fn main() {
  parse_model()
  print_base_framework()
}

fn lexer() {
  lexer.simple([
    lexer.keyword("classifier", " ", Keyword(Classifier)),
    lexer.keyword("feature", " ", Keyword(Feature)),
    lexer.keyword("typed by", " ", FeatureRelation(TypedBy)),
    lexer.keyword("subsets", " ", FeatureRelation(Subsets)),
    lexer.keyword("redefines", " ", FeatureRelation(Redefines)),
    lexer.keyword(":>", " ", FeatureRelation(Subsets)),
    lexer.keyword(":>>", " ", FeatureRelation(Redefines)),
    lexer.keyword("specializes", " ", ClassifierRelation(Specializes)),
    lexer.int(Integer),
    lexer.identifier(
      "[a-zA-Z]",
      "[a-zA-z]",
      set.new() |> set.insert("typed"),
      Name,
    ),
    lexer.token("[", LBracket),
    lexer.token("..", Until),
    lexer.token("]", RBracket),
    lexer.token("{", LBrace),
    lexer.token("}", RBrace),
    lexer.keyword(":", " ", Colon),
    lexer.token(";", Semicolon),
    lexer.whitespace(Nil) |> lexer.ignore,
  ])
}

fn parse_model() {
  let text =
    simplifile.read("model.kerml")
    |> result.unwrap("")

  let assert Ok(tokens) = lexer.run(text, lexer())
  io.println("List of tokens: \n")
  io.debug(tokens)
  io.println("\n\n")
  case tokens |> nibble.run(file_parser()) {
    Ok(value) -> {
      let _ = simplifile.write("./generated.problem", value)
      io.println("Generated model:\n\n")
      io.println(value)
    }
    Error(err) -> {
      io.println("Generating failed:\n\n")
      io.debug(err)
      Nil
    }
  }
}

fn file_parser() {
  use stuff <- do(nibble.many(classifier_parser()))
  nibble.return(stuff |> string.join("\n"))
}

fn classifier_parser() {
  use classifier <- do(
    nibble.one_of([
      nibble.backtrackable(bodyless_classifier_parser()),
      nibble.backtrackable(bodied_classifier_parser()),
    ]),
  )
  nibble.return(classifier)
}

fn bodyless_classifier_parser() {
  use _ <- do(nibble.token(Keyword(Classifier)))
  use name <- do(name_parser())
  use _ <- do(nibble.token(Semicolon))
  nibble.return(classifier_template(name, []))
}

fn bodied_classifier_parser() {
  use _ <- do(nibble.token(Keyword(Classifier)))
  use name <- do(name_parser())
  use _ <- do(nibble.token(LBrace))
  use body <- do(nibble.many(feature_parser(name)))
  use _ <- do(nibble.token(RBrace))
  nibble.return(classifier_template(name, body))
}

fn feature_parser(classifier: String) {
  use _ <- do(nibble.token(Keyword(Feature)))
  use fname <- do(name_parser())

  use fs <- do(
    nibble.many(
      nibble.one_of([
        subsetting_parser(fname),
        typed_by_parser(fname),
        redefinition_parser(fname),
      ]),
    ),
  )
  use _ <- do(nibble.token(Semicolon))
  nibble.return(feature_template(classifier, fname, fs))
}

fn name_parser() {
  use token <- nibble.take_map("expected name")
  case token {
    Name(n) -> Some(n)
    _ -> None
  }
}

fn subsetting_parser(feature: String) {
  use _ <- do(nibble.token(FeatureRelation(Subsets)))
  use name <- do(name_parser())
  nibble.return(subsetting_template(feature, name))
}

fn typed_by_parser(feature: String) {
  use _ <- do(
    nibble.one_of([nibble.token(FeatureRelation(TypedBy)), nibble.token(Colon)]),
  )
  use name <- do(name_parser())
  nibble.return(typed_by_template(feature, name))
}

fn redefinition_parser(feature: String) {
  use _ <- do(nibble.token(FeatureRelation(Redefines)))
  use name <- do(name_parser())
  nibble.return(redefinition_template(feature, name))
}

fn subsetting_template(f: String, subsetted: String) {
  "directSubsettedFeature("
  <> f
  <> ", "
  <> subsetted
  <> ").\n"
  <> "directSpecializedType("
  <> f
  <> ", "
  <> subsetted
  <> ")."
}

fn typed_by_template(f: String, typed_by: String) {
  "featureTyping("
  <> f
  <> ", "
  <> typed_by
  <> ").\n"
  <> "directSpecializedType("
  <> f
  <> ", "
  <> typed_by
  <> ")."
}

fn redefinition_template(f: String, redefined: String) {
  "directRedefinedFeature("
  <> f
  <> ", "
  <> redefined
  <> ").\n"
  <> "directSubsettedFeature("
  <> f
  <> ", "
  <> redefined
  <> ").\n"
  <> "directSpecializedType("
  <> f
  <> ", "
  <> redefined
  <> ")."
}

fn feature_template(c: String, f: String, others: List(String)) {
  "Feature("
  <> f
  <> ")."
  <> "\n"
  <> "typeFeaturing("
  <> c
  <> ", "
  <> f
  <> ")."
  <> "\n"
  <> "directSubsettedFeature("
  <> f
  <> ", things)."
  <> "\n"
  <> "directSpecializedType("
  <> f
  <> ", things)."
  <> "\n"
  <> others |> string.join("\n")
  <> "\n"
}

fn classifier_template(c: String, body: List(String)) {
  "Classifier("
  <> c
  <> ")."
  <> "\n"
  <> "directSuperclass("
  <> c
  <> ", Anything)."
  <> "\n"
  <> "directSpecializedType("
  <> c
  <> ", Anything)."
  <> "\n"
  <> "\n"
  <> body |> string.join("\n")
  <> "\n"
}

fn print_base_framework() {
  simplifile.append(
    "./generated.problem",
    "
//Base framework
abstract class Type {
    Type[0..*] directSpecializedType
    
}
default !directSpecializedType(*, *).

pred specializedType(Type sub, Type super) <->
    directSpecializedType+(sub, super).

class Classifier extends Type {
    Classifier[0..*] directSuperclass subsets directSpecializedType
    Feature[0..*] typeFeaturing
}
!exists(Classifier::new).
default !typeFeaturing(*, *).
pred superclass(Classifier sub, Classifier super) <->
    directSuperclass+(sub, super).

Classifier(Anything). atom Anything.

class Feature extends Type {
    Classifier[1..*] featureTyping subsets directSpecializedType
    Feature[0..*] directSubsettedFeature subsets directSpecializedType
    Feature[0..*] directRedefinedFeature subsets directSubsettedFeature
}
!exists(Feature::new).
default !featureTyping(*, *).
default !directSubsettedFeature(*, *).
default !directRedefinedFeature(*, *).
pred subsettedFeature(Feature sub, Feature super) <->
    directSubsettedFeature+(sub,super)
.
pred redefinedFeature(Feature sub, Feature super) <->
    directRedefinedFeature(sub, super)
.

Feature(things). atom things.
typeFeaturing(Anything, things).
featureTyping(things, Anything).
directSpecializedType(things, Anything).

class Atom {
    Classifier[1] of
}

class FeatureAtom {
    Feature[1] of
    Atom[1] domain
    Atom[1] value
}

pred CorrectFeatureAtom(FeatureAtom a) <->
    typeFeaturing(tft, f),
    featureTyping(f, ftt),
    FeatureAtom::of(a, f),
    FeatureAtom::domain(a, da),
    FeatureAtom::value(a, va),
    Atom::of(da, tft),
    Atom::of(va, ftt).

propagation rule FeaturesSubsetThings(Feature f) <->
    f != things
==>
    subsettedFeature(f, things).

propagation rule ClassifiersSubclassifyAnyting(Classifier c) <->
    c != Anything
==>
    superclass(c, Anything).

error pred IncorrectFeatureAtom(FeatureAtom a) <->
    !CorrectFeatureAtom(a).


error pred AtomWithoutFeatures(Atom a) <->
    Atom::of(a, c),
    typeFeaturing(c, f),
    !FeatureAtom::of(_fa, f)
    ;
    Atom::of(a, c),
    typeFeaturing(c, f),
    !FeatureAtom::domain(fa, a),
    FeatureAtom::of(fa, f)
.",
  )
}
