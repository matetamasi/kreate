package hu.bme.mit.kerml.kreate.jobs;
//from gamma
import java.nio.file.Path;
import java.util.List;
import java.util.stream.Collectors;

import org.eclipse.core.commands.ExecutionEvent;
import org.eclipse.core.resources.IFile;
import org.eclipse.core.runtime.FileLocator;
import org.eclipse.core.runtime.IPath;
import org.eclipse.core.runtime.IProgressMonitor;
import org.eclipse.core.runtime.IStatus;
import org.eclipse.core.runtime.OperationCanceledException;
import org.eclipse.core.runtime.SubMonitor;
import org.eclipse.core.runtime.jobs.Job;
import org.eclipse.emf.common.util.EList;
import org.eclipse.emf.common.util.URI;
import org.eclipse.emf.ecore.EObject;
import org.eclipse.emf.ecore.resource.Resource;
import org.eclipse.emf.ecore.resource.ResourceSet;
import org.eclipse.emf.ecore.resource.impl.ResourceSetImpl;
import org.eclipse.jface.viewers.ISelection;
import org.eclipse.jface.viewers.IStructuredSelection;
import org.eclipse.ui.handlers.HandlerUtil;
import org.osgi.framework.FrameworkUtil;

import hu.bme.mit.kerml.kreate.KreateTranslationHandler;

import org.eclipse.emf.ecore.util.EcoreUtil;

public class FileScannerJob extends Job {

	private final JobReporter reporter;
	private final ExecutionEvent event;
	
	protected final EcoreUtil ecoreUtil = new EcoreUtil();

	public FileScannerJob(String name, JobReporter reporter, ExecutionEvent event) {
		super(name);
		this.reporter = reporter;
		this.event = event;
	}

	@Override
	protected IStatus run(IProgressMonitor monitor) {
		SubMonitor mainMonitor = SubMonitor.convert(monitor, 100);

		ISelection sel = HandlerUtil.getActiveMenuSelection(event);
		try {

			// Process input file
			List<IFile> files = getSelectedFile(mainMonitor.split(5), sel);
			if(files.size() > 1) {
				throw new RuntimeException("Generating multiple files at once is currently unsupported");
			}
			

			SubMonitor fileMonitor = mainMonitor.split(95);
			fileMonitor.setWorkRemaining(files.size() * 10);
			for (IFile file : files) {
				String fileName = file.getFullPath().removeFileExtension().lastSegment();
				var outFile = file.getLocation().removeLastSegments(1).toPath().toAbsolutePath().resolve(fileName + "-executionResult.kerml");
				System.out.println(outFile.toString());

				EObject object = loadRootObject(fileMonitor.split(9), file.getFullPath().toString());
	            List<EObject> objects = getAllEObjects(object.eResource().getResourceSet());
				
				Runner runner = new Runner();
				runner.run(object, objects, outFile);

			}

			mainMonitor.setTaskName("Done.");
			mainMonitor.setWorkRemaining(0);
		} catch (OperationCanceledException ex) {
			throw ex;
		} catch (Exception exception) {
			String prefix = "An unexpected error occured: ";
			return reporter.reportError(exception, prefix);
		}

		return org.eclipse.core.runtime.Status.OK_STATUS;
	}

	private List<IFile> getSelectedFile(SubMonitor subMonitor, ISelection sel) throws Exception {
		reporter.reportTaskStart(subMonitor, "Processing selection...");

		if (!(sel instanceof IStructuredSelection)) {
			throw new RuntimeException("Invalid selection.");
		}

		IStructuredSelection selection = (IStructuredSelection) sel;
		if (selection.isEmpty()) {
			throw new RuntimeException("No file is selected.");
		}

		@SuppressWarnings("unchecked")
		List<IFile> files = (List<IFile>) selection.toList().stream().filter(it -> it instanceof IFile)
				.collect(Collectors.toList());
		if (files.isEmpty()) {
			throw new RuntimeException("Selected element is not a file.");
		}

		reporter.reportTaskEnd(subMonitor, "Selected files: " +
			files.stream().map(it -> it.getName()).collect(Collectors.joining(", ")) + ".");
		return files;
	}

	private EObject loadRootObject(SubMonitor subMonitor, String path) {
		if (subMonitor != null) {
			reporter.reportTaskStart(subMonitor, "Loading file " + path + "...");
		}

		URI relativeUri = URI.createPlatformResourceURI(path, true);
		
		ResourceSet resourceSet = new ResourceSetImpl();
		Resource resource = resourceSet.getResource(relativeUri, true);
		EObject object = resource.getContents().get(0);

		if (KreateTranslationHandler.RESOLVE_ALL) {
			resource = object.eResource();
			resourceSet = resource.getResourceSet();
			EcoreUtil.resolveAll(resourceSet); // Can be resource-intensive due to the huge library
		}
		if (subMonitor != null) {
			reporter.reportTaskEnd(subMonitor, "File " + path + " loaded.");
		}
		return object;
	}
	
	// Method to collect all EObjects from a ResourceSet
	private List<EObject> getAllEObjects(ResourceSet resourceSet) {
		EList<Resource> rs = resourceSet.getResources();
		return rs.stream().map(r ->
			r.getContents().get(0)).toList();
	}
}