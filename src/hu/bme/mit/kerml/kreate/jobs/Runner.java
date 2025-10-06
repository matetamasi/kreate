package hu.bme.mit.kerml.kreate.jobs;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Collection;
import java.util.List;

import org.eclipse.emf.ecore.EObject;

public class Runner {
	public void run(EObject root, Collection<EObject> roots, Path outFile) {
		String result = ObjectProcessor.translateRoot(root, roots, outFile.getFileName().toString().replaceAll("\\..*", "").replaceAll("-", "_"));
		try {
			if (Files.exists(outFile)) {
				Files.delete(outFile);
			}
			Files.createFile(outFile);
			Files.writeString(outFile, result);
		} catch (IOException | NullPointerException e)  {
			System.err.println("Writing to file failed due to exception");
			e.printStackTrace();
			System.err.println("Writing result to standard output...");
			System.out.println(result);
		}
	}
	
}