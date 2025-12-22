import org.cyclos.entities.banking.ChargebackTransfer
import org.cyclos.entities.banking.Transfer
import org.cyclos.entities.banking.TransferStatus
import org.cyclos.entities.banking.TransferStatusFlow
import org.cyclos.entities.system.ExtensionPoint
import org.cyclos.model.system.extensionpoints.ExtensionPointEvent

ChargebackTransfer chargeback = binding.chargeback
String comments = binding.comments
Map<String, Object> context = binding.context
ExtensionPointEvent event = binding.event
ExtensionPoint extensionPoint = binding.extensionPoint
TransferStatusFlow flow = binding.flow
TransferStatus newtatus = binding.newtatus
TransferStatus oldStatus = binding.oldStatus
Transfer transfer = binding.transfer

throw new UnsupportedOperationException('Script not implemented')