// Reference copy of internal/controller/replicapin_controller.go from the A1 lab.
// The reconcile loop: observe desired (ReplicaPin) -> observe actual (Deployment) -> act (scale).
package controller

import (
	"context"
	"time"

	appsv1 "k8s.io/api/apps/v1"
	"k8s.io/apimachinery/pkg/runtime"
	"k8s.io/apimachinery/pkg/types"
	ctrl "sigs.k8s.io/controller-runtime"
	"sigs.k8s.io/controller-runtime/pkg/client"
	"sigs.k8s.io/controller-runtime/pkg/log"

	opsv1 "quarx.co/replicapin/api/v1"
)

type ReplicaPinReconciler struct {
	client.Client
	Scheme *runtime.Scheme
}

// +kubebuilder:rbac:groups=ops.quarx.co,resources=replicapins,verbs=get;list;watch;create;update;patch;delete
// +kubebuilder:rbac:groups=ops.quarx.co,resources=replicapins/status,verbs=get;update;patch
// +kubebuilder:rbac:groups=apps,resources=deployments,verbs=get;list;watch;update;patch

func (r *ReplicaPinReconciler) Reconcile(ctx context.Context, req ctrl.Request) (ctrl.Result, error) {
	l := log.FromContext(ctx)

	// OBSERVE desired state — the ReplicaPin object
	var pin opsv1.ReplicaPin
	if err := r.Get(ctx, req.NamespacedName, &pin); err != nil {
		return ctrl.Result{}, client.IgnoreNotFound(err)
	}

	// OBSERVE actual state — the target Deployment (same namespace)
	var dep appsv1.Deployment
	depKey := types.NamespacedName{Namespace: pin.Namespace, Name: pin.Spec.DeploymentName}
	if err := r.Get(ctx, depKey, &dep); err != nil {
		l.Error(err, "target Deployment not found", "deployment", pin.Spec.DeploymentName)
		return ctrl.Result{RequeueAfter: 10 * time.Second}, client.IgnoreNotFound(err)
	}

	// COMPARE + ACT — drive the Deployment's replicas to the desired count
	want := pin.Spec.Replicas
	if dep.Spec.Replicas == nil || *dep.Spec.Replicas != want {
		l.Info("reconcile: pinning replicas", "deployment", dep.Name, "to", want)
		dep.Spec.Replicas = &want
		if err := r.Update(ctx, &dep); err != nil {
			return ctrl.Result{}, err
		}
	}

	// Level-triggered resync so drift is corrected even without an event.
	// Production upgrade: add .Owns(&appsv1.Deployment{}) below to react to Deployment changes instantly.
	return ctrl.Result{RequeueAfter: 10 * time.Second}, nil
}

func (r *ReplicaPinReconciler) SetupWithManager(mgr ctrl.Manager) error {
	return ctrl.NewControllerManagedBy(mgr).
		For(&opsv1.ReplicaPin{}).
		Named("replicapin").
		Complete(r)
}
