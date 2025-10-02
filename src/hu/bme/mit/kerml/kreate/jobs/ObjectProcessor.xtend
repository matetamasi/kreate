package hu.bme.mit.kerml.kreate.jobs

import org.eclipse.emf.ecore.EObject
import org.omg.sysml.lang.sysml.Namespace
import org.omg.sysml.lang.sysml.Package
import java.util.Collection
import org.omg.sysml.lang.sysml.Classifier
import hu.bme.mit.kerml.kreate.Translator

class ObjectProcessor {
	static def dispatch void translateRoot(Classifier classifier, Collection<EObject> roots) {
		try {
			System.out.println("Classifier: " + getName(classifier))
			if ("ToExecute".equals(classifier.effectiveName)) {
				System.out.println("Found classifier ToExecute")
				var translation = Translator.translate(classifier, roots);
				println("--------------------------------------------------")
				println(Translator.userModelComment + translation + Translator.metaModel);
			}
		} catch(StackOverflowError e) {
			throw new StackOverflowError("Failed to translate package: " + getName(classifier) + "\n" + e.message)
		}
	}
	static def dispatch void translateRoot(Namespace namespace, Collection<EObject> roots) {
		try {
			System.out.println("Namespace: " + namespace.effectiveName)
			for (member : namespace.member) {
				translateRoot(member, roots)
			}
		} catch(StackOverflowError e) {
			throw new StackOverflowError("Failed to translate namespace: " + namespace.effectiveName + "\n" + e.message)
		}
	}
	static def dispatch void translateRoot(Package pack, Collection<EObject> roots) {
		try {
			System.out.println("Package: " + pack.effectiveName)
			for (member : pack.member) {
				translateRoot(member, roots)
			}
		} catch(StackOverflowError e) {
			throw new StackOverflowError("Failed to translate classifier: " + pack.effectiveName + "\n" + e.message)
		}
	}

	static def dispatch void translateRoot(EObject object, Collection<EObject> roots) {
		//System.out.println("Can't handle EObject: " + object)
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