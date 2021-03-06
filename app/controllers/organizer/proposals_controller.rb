class Organizer::ProposalsController < Organizer::ApplicationController
  before_filter :require_proposal, except: [ :index, :new, :create ]

  decorates_assigned :proposal, with: Organizer::ProposalDecorator

  def finalize
    @proposal.finalize
    send_state_mail(@proposal.state)
    redirect_to organizer_event_proposal_path(@proposal.event, @proposal)
  end

  def update_state
    @proposal.update_state(params[:new_state])

    respond_to do |format|
      format.html { redirect_to organizer_event_proposals_path(@proposal.event) }
      format.js
    end
  end

  def index
    proposals = @event.proposals.includes(:review_taggings, :proposal_taggings, :ratings, {speakers: :person}).load

    session[:prev_page] = { name: 'Proposals', path: organizer_event_proposals_path }

    taggings_count = Tagging.count_by_tag(@event)

    proposals = Organizer::ProposalsDecorator.decorate(proposals)
    respond_to do |format|
      format.html { render locals: { event: @event, proposals: proposals, taggings_count: taggings_count} }
      format.csv { render text: proposals.to_csv }
    end
  end

  def show
    render locals: {
      speakers: @proposal.speakers.decorate,
      rating: current_user.rating_for(@proposal)
    }
  end

  def edit
  end

  def update
    if @proposal.update_attributes(proposal_params)
      flash[:info] = 'Proposal Updated'
      redirect_to organizer_event_proposals_path(slug: @event.slug)
    else
      flash[:danger] = 'There was a problem saving your proposal; please review the form for issues and try again.'
      render :edit
    end
  end

  def destroy
    @proposal.destroy
    flash[:info] = "Your proposal has been deleted."
    redirect_to organizer_event_proposals_path(@event)
  end

  def new
    @proposal = @event.proposals.new
  end

  def create
    altered_params = proposal_params.merge!("state" => "accepted", "confirmed_at" => DateTime.now)
    @proposal = @event.proposals.new(altered_params)
    if @proposal.save
      flash[:success] = 'Proposal Added'
      redirect_to organizer_event_program_path(@event)
    else
      flash.now[:danger] = 'There was a problem saving your proposal; please review the form for issues and try again.'
      render :new
    end
  end

  private

  def proposal_params
    # add updating_person to params so Proposal does not update last_change attribute when updating_person is organizer_for_event?
    params.require(:proposal).permit(:title, {review_tags: []}, :abstract, :details, :pitch,
                                     comments_attributes: [:body, :proposal_id, :person_id],
                                     speakers_attributes: [:bio, :person_id, :id]).merge(updating_person: current_user)
  end

  def send_state_mail(state)
    case state
    when Proposal::State::ACCEPTED
      Organizer::ProposalMailer.accept_email(@event, @proposal).deliver
    when Proposal::State::REJECTED
      Organizer::ProposalMailer.reject_email(@event, @proposal).deliver
    when Proposal::State::WAITLISTED
      Organizer::ProposalMailer.waitlist_email(@event, @proposal).deliver
    end
  end
end
