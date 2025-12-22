import org.cyclos.entities.banking.Account
import org.cyclos.entities.banking.AuthorizationLevel
import org.cyclos.entities.banking.Installment
import org.cyclos.entities.banking.PaymentTransferType
import org.cyclos.entities.banking.Transaction
import org.cyclos.entities.system.ExtensionPoint
import org.cyclos.impl.banking.LocateAccountOwnerResult
import org.cyclos.model.banking.accounts.AccountOwner
import org.cyclos.model.banking.accounts.InternalAccountOwner
import org.cyclos.model.banking.transactions.PerformTransactionDTO
import org.cyclos.model.banking.transactions.TransactionAuthorizationType
import org.cyclos.model.banking.transactions.TransactionPreviewVO
import org.cyclos.model.banking.transactions.TransactionStatus
import org.cyclos.model.system.extensionpoints.ExtensionPointEvent

AuthorizationLevel authorizationLevel = binding.authorizationLevel
TransactionAuthorizationType authorizationType = binding.authorizationType
Map<String, Object> context = binding.context
ExtensionPointEvent event = binding.event
ExtensionPoint extensionPoint = binding.extensionPoint
Account fromAccount = binding.fromAccount
InternalAccountOwner fromOwner = binding.fromOwner
LocateAccountOwnerResult fromOwnerResult = binding.fromOwnerResult
Installment installment = binding.installment
TransactionStatus newtatus = binding.newtatus
TransactionStatus oldStatus = binding.oldStatus
PaymentTransferType paymentType = binding.paymentType
PerformTransactionDTO performTransaction = binding.performTransaction
TransactionPreviewVO preview = binding.preview
Account toAccount = binding.toAccount
AccountOwner toOwner = binding.toOwner
LocateAccountOwnerResult toOwnerResult = binding.toOwnerResult
Transaction transaction = binding.transaction

throw new UnsupportedOperationException('Script not implemented')