import org.cyclos.entities.banking.Voucher
import org.cyclos.entities.system.ExtensionPoint
import org.cyclos.entities.users.User
import org.cyclos.model.banking.vouchers.VoucherStatus
import org.cyclos.model.system.extensionpoints.ExtensionPointEvent

BigDecimal amount = binding.amount
Map<String, Object> context = binding.context
ExtensionPointEvent event = binding.event
ExtensionPoint extensionPoint = binding.extensionPoint
VoucherStatus previousStatus = binding.previousStatus
User user = binding.user
Voucher voucher = binding.voucher

throw new UnsupportedOperationException('Script not implemented')