import org.cyclos.entities.banking.AuthorizationLevel
import org.cyclos.entities.banking.BasePayment
import org.cyclos.entities.system.ExtensionPoint
import org.cyclos.model.system.extensionpoints.ExtensionPointEvent

String comment = binding.comment
Map<String, Object> context = binding.context
AuthorizationLevel currentLevel = binding.currentLevel
ExtensionPointEvent event = binding.event
ExtensionPoint extensionPoint = binding.extensionPoint
AuthorizationLevel nextLevel = binding.nextLevel
BasePayment transaction = binding.transaction

throw new UnsupportedOperationException('Script not implemented')