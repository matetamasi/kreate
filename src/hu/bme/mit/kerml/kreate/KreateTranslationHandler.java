package hu.bme.mit.kerml.kreate;

import java.util.logging.Logger;

import org.eclipse.core.commands.AbstractHandler;
import org.eclipse.core.commands.ExecutionEvent;
import org.eclipse.core.commands.ExecutionException;
import org.eclipse.core.runtime.jobs.Job;

import hu.bme.mit.kerml.kreate.jobs.FileScannerJob;
import hu.bme.mit.kerml.kreate.jobs.JobReporter;
public final class KreateTranslationHandler extends AbstractHandler {
	public static final boolean RESOLVE_ALL = false;
	protected final Logger logger = Logger.getLogger("KreateLogger");

	@Override
	public Object execute(ExecutionEvent event) throws ExecutionException {
		Job job = new FileScannerJob("Parsing KerML files...", new JobReporter(logger), event);
		job.setUser(true);
		job.setPriority(Job.LONG);
		job.schedule();
		return null;
	}

}
