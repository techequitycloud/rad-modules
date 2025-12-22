import org.cyclos.entities.SimpleEntity
import org.cyclos.entities.system.ExtensionPoint
import org.cyclos.entities.system.ImportedFile
import org.cyclos.entities.system.ImportedLine
import org.cyclos.model.system.extensionpoints.ExtensionPointEvent
import org.cyclos.model.system.imports.ImportedFileStatus

Map<String, Object> context = binding.context
SimpleEntity entity = binding.entity
Exception error = binding.error
ExtensionPointEvent event = binding.event
ExtensionPoint extensionPoint = binding.extensionPoint
ImportedFile importedFile = binding.importedFile
ImportedLine line = binding.line
ImportedFileStatus newStatus = binding.newStatus
ImportedFileStatus oldStatus = binding.oldStatus

throw new UnsupportedOperationException('Script not implemented')