package hu.bme.mit.kerml.kreate.jobs;

import java.util.Collection;

import org.eclipse.emf.ecore.EObject;

public class Runner {
	public void run(EObject root, Collection<EObject> roots) {
		System.out.println("Hello KerML");
		ObjectProcessor.translateRoot(root, roots);
	}
}