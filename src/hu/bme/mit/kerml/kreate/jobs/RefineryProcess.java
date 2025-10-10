package hu.bme.mit.kerml.kreate.jobs;

import java.io.File;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.nio.file.StandardCopyOption;
import java.util.logging.Logger;
import java.util.stream.Stream;

import org.eclipse.core.runtime.FileLocator;
import org.osgi.framework.Bundle;
import org.osgi.framework.FrameworkUtil;

public class RefineryProcess {
	protected final static Logger logger = Logger.getLogger("KreateLogger");
	public static String concretize(String partialModel) throws IOException, InterruptedException {
		Bundle bundle = FrameworkUtil.getBundle(RefineryProcess.class);
		Path rootDir = FileLocator.getBundleFileLocation(bundle).get().toPath();
		Path sourceDir = Paths.get(rootDir.toString()+"/refineryJar");
        Path temp = Files.createTempDirectory("refineryPacage");
		try (Stream<Path> stream = Files.walk(sourceDir)) {
	        stream.forEach(source -> copy(source, temp.resolve(sourceDir.relativize(source))));
	    }
		Path generated = Paths.get(rootDir.toString() + "/generated.problem");
		Path executed = Paths.get(rootDir.toString() + "/executed.problem");
		Integer exitCode = null;	
        File script = Paths.get(temp.toString() + "/bin/refinery-generator-cli").toFile();
        script.setExecutable(true);
        
        logger.info("Writing partial model to file: " + generated.toString());
        Files.writeString(generated, partialModel);

        logger.info("Starting Refinery process...");
        exitCode = new ProcessBuilder("sh", script.toString(), "g", generated.toString(), "-o", executed.toString()).inheritIO().start().waitFor();

        logger.info("Refinery process returned with exit code: " + exitCode);
		
		if (exitCode != 0) {
			throw new RuntimeException("Refinery process quit with non-zero exit code " + exitCode);
		}
        logger.info("Execution result written to file: " + executed.toString());
		return Files.readString(executed);
	}
	
	private static void copy(Path source, Path dest) {
	    try {
	        Files.copy(source, dest, StandardCopyOption.REPLACE_EXISTING);
	    } catch (Exception e) {
	        throw new RuntimeException(e.getMessage(), e);
	    }
	}
}