package hu.bme.mit.kerml.kreate.jobs

import org.eclipse.emf.ecore.EObject
import org.omg.sysml.lang.sysml.Namespace
import org.omg.sysml.lang.sysml.Package
import java.util.Collection
import org.omg.sysml.lang.sysml.Classifier
import hu.bme.mit.kerml.kreate.Translator
import hu.bme.mit.kerml.kreate.Backannotator

class ObjectProcessor {
	static def dispatch String translateRoot(Classifier classifier, Collection<EObject> roots, String packageName) {
		try {
			if ("ToExecute".equals(classifier.effectiveName)) {
				var translation = Translator.translate(classifier, roots);
				var concreteModel = RefineryProcess.concretize(Translator.userModelComment + translation + Translator.metaModel)
				return Backannotator.toKerml(concreteModel, packageName)
			}
			return ""
		} catch(StackOverflowError e) {
			throw new StackOverflowError("Failed to translate package: " + getName(classifier) + "\n" + e.message)
		}
	}
	static def dispatch String translateRoot(Namespace namespace, Collection<EObject> roots, String packageName) {
		try {
			var r = "";
			for (member : namespace.member) {
				r += translateRoot(member, roots, packageName)
			}
			return r
		} catch(StackOverflowError e) {
			throw new StackOverflowError("Failed to translate namespace: " + namespace.effectiveName + "\n" + e.message)
		}
	}
	static def dispatch String translateRoot(Package pack, Collection<EObject> roots, String packageName) {
		try {
			var r = "";
			for (member : pack.member) {
				r += translateRoot(member, roots, packageName)
			}
			return r
		} catch(StackOverflowError e) {
			throw new StackOverflowError("Failed to translate classifier: " + pack.effectiveName + "\n" + e.message)
		}
	}

	static def dispatch String translateRoot(EObject object, Collection<EObject> roots, String packageName) {
		return ""
	}
	
	private static def String getName(Classifier c) {
		if (c.declaredName !== null) return c.declaredName
		else if (c.effectiveName !== null) return c.effectiveName
		else if (c.name !== null) return c.name
		else if (c.declaredShortName !== null) return c.declaredShortName
		else if (c.effectiveShortName !== null) return c.effectiveShortName
		else if (c.qualifiedName !== null) return c.qualifiedName
		else return "/no name found/"
	}
}